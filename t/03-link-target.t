#!/usr/bin/env perl
#
# 03-link-target.t - Tests for Symlish::LinkTarget module
#
# Tests target resolution, path expansion, and glob pattern matching.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use lib "$RealBin/lib";

use Symlish::LinkTarget;
use SymlishTest qw(write_file);

#=============================================================================
# Test: Constructor creates object
#=============================================================================
subtest 'Constructor' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    my $src_dir = File::Spec->catdir($tempdir, 'bash');
    
    make_path($dest_dir);
    make_path($src_dir);
    write_file(File::Spec->catfile($src_dir, '.bashrc'), 'test');
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$dest_dir],
        },
        config_dir => $tempdir,
    );
    
    isa_ok($target, 'Symlish::LinkTarget');
    is($target->key, 'bash', 'key accessor works');
    is($target->path, $dest_dir, 'path resolved correctly');
    ok($target->is_valid, 'is_valid returns true when path exists');
};

#=============================================================================
# Test: Path resolution with multiple candidates
#=============================================================================
subtest 'Path resolution - first valid wins' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $first_dir = File::Spec->catdir($tempdir, 'first');
    my $second_dir = File::Spec->catdir($tempdir, 'second');
    my $src_dir = File::Spec->catdir($tempdir, 'test');
    
    # Only create second_dir
    make_path($second_dir);
    make_path($src_dir);
    write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => [$first_dir, $second_dir],
        },
        config_dir => $tempdir,
    );
    
    is($target->path, $second_dir, 'Falls back to second path when first does not exist');
};

#=============================================================================
# Test: No valid path found
#=============================================================================
subtest 'No valid path found' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $src_dir = File::Spec->catdir($tempdir, 'test');
    make_path($src_dir);
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => ['/nonexistent/path1', '/nonexistent/path2'],
        },
        config_dir => $tempdir,
    );
    
    ok(!$target->is_valid, 'is_valid returns false when no path exists');
    ok(!defined $target->path, 'path is undef when no valid path');
};

#=============================================================================
# Test: Environment variable expansion
#=============================================================================
subtest 'Environment variable expansion' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $src_dir = File::Spec->catdir($tempdir, 'test');
    make_path($src_dir);
    write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');
    
    # Set environment variable
    local $ENV{TEST_SYMLISH_PATH} = $tempdir;
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => ['$TEST_SYMLISH_PATH'],
        },
        config_dir => $tempdir,
    );
    
    is($target->path, $tempdir, 'Environment variable expanded correctly');
    ok($target->is_valid, 'Path with env var is valid');
};

#=============================================================================
# Test: Tilde expansion
#=============================================================================
# Pin HOME (and USERPROFILE for the Windows fallback) to the tempdir so the
# assertion below is deterministic regardless of the environment the test
# is run in. Without this, an unset HOME on Winodws would compare undef vs 
# whatever the fallback produced.
subtest 'Tilde expansion' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $src_dir = File::Spec->catdir($tempdir, 'test');
    make_path($src_dir);
    write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');

    local $ENV{HOME}        = $tempdir;
    local $ENV{USERPROFILE} = $tempdir;
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => ['~'],  # Home directory
        },
        config_dir => $tempdir,
    );
    
    is($target->path, $tempdir, 'Tilde expanded to home directory');
};

#=============================================================================
# Test: Glob expansion - single asterisk
#=============================================================================
subtest 'Glob expansion - single asterisk' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    my $src_dir = File::Spec->catdir($tempdir, 'bash');
    
    make_path($dest_dir);
    make_path($src_dir);
    write_file(File::Spec->catfile($src_dir, '.bashrc'), 'bashrc');
    write_file(File::Spec->catfile($src_dir, '.bash_profile'), 'profile');
    write_file(File::Spec->catfile($src_dir, 'visible.txt'), 'visible');
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$dest_dir],
        },
        config_dir => $tempdir,
    );
    
    my @items = $target->items;
    ok(scalar(@items) >= 1, 'Items created from glob');
    
    # Check that we got the expected files
    my %sources = map { $_->source => 1 } @items;
    ok($sources{File::Spec->catfile($src_dir, 'visible.txt')}, 
        'Regular file included');
};

#=============================================================================
# Test: Dotfiles are included
#=============================================================================
subtest 'Dotfiles are included' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    my $src_dir = File::Spec->catdir($tempdir, 'bash');
    
    make_path($dest_dir);
    make_path($src_dir);
    write_file(File::Spec->catfile($src_dir, '.bashrc'), 'bashrc');
    write_file(File::Spec->catfile($src_dir, '.profile'), 'profile');
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$dest_dir],
        },
        config_dir => $tempdir,
    );
    
    my @items = $target->items;
    my %sources = map { $_->source => 1 } @items;
    
    ok($sources{File::Spec->catfile($src_dir, '.bashrc')}, 
        'Dotfile .bashrc included');
    ok($sources{File::Spec->catfile($src_dir, '.profile')}, 
        'Dotfile .profile included');
};

#=============================================================================
# Test: ignore flag
#=============================================================================
subtest 'ignore flag' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    make_path($dest_dir);
    
    my $target_ignored = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => [$dest_dir],
            ignore => 'true',
        },
        config_dir => $tempdir,
    );
    ok($target_ignored->ignore, 'ignore flag set to true');
    
    my $target_not_ignored = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => [$dest_dir],
            ignore => 'false',
        },
        config_dir => $tempdir,
    );
    ok(!$target_not_ignored->ignore, 'ignore flag set to false');
};

#=============================================================================
# Test: ignore-empty = false is honoured
#=============================================================================
subtest 'ignore-empty flag set to false' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    make_path($dest_dir);
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target          => 'test/*',
            paths           => [$dest_dir],
            'ignore-empty'  => 'false',
        },
        config_dir => $tempdir,
    );
    
    ok(!$target->ignore_empty, 'ignore_empty is false when explicitly disabled');
};

#=============================================================================
# Test: ignore-empty flag defaults to true
#=============================================================================
subtest 'ignore-empty flag defaults' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    make_path($dest_dir);
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => [$dest_dir],
        },
        config_dir => $tempdir,
    );
    
    ok($target->ignore_empty, 'ignore_empty defaults to true');
};

#=============================================================================
# Test: conflict default value
#=============================================================================
subtest 'conflict default value' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    make_path($dest_dir);
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => [$dest_dir],
        },
        config_dir => $tempdir,
    );
    
    is($target->conflict, 'skip', 'conflict defaults to skip');
};

#=============================================================================
# Test: Target path mapping
#=============================================================================
subtest 'Target path mapping' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    my $src_dir = File::Spec->catdir($tempdir, 'config');
    
    make_path($dest_dir);
    make_path($src_dir);
    write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');
    
    my $target = Symlish::LinkTarget->new(
        key => 'config',
        entry => {
            target => 'config/*',
            paths => [$dest_dir],
        },
        config_dir => $tempdir,
    );
    
    my @items = $target->items;
    is(scalar(@items), 1, 'One item created');
    
    my $item = $items[0];
    is($item->source, File::Spec->catfile($src_dir, 'file.txt'), 
        'Source path is correct');
    is($item->target, File::Spec->catfile($dest_dir, 'file.txt'), 
        'Target path strips source directory component');
};

#=============================================================================
# Reverse config tests
#=============================================================================
# From 1.1.0, reverse config is supported, flipping the typical usage:
# Source files live somewhere on the filesystem (e.g. /etc/something/*) and the
# symlinks are created INSIDE a specified directory, "collecting" them 
# in a central location. The 'paths' entry is then a subdirectory of $config_dir
# rather than an absolute system location.
#=============================================================================

#=============================================================================
# Test: Reverse config - absolute target, config-dir-relative path
#=============================================================================
subtest 'Reverse config: absolute target with single file' => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    # External source: a file somewhere on the filesystem
    my $external_dir = File::Spec->catdir($tempdir, 'external');
    make_path($external_dir);
    
    my $source_file = File::Spec->catfile($external_dir, 'one.conf');
    write_file($source_file, 'content');

    # Central location with a "collected" subdirectory to hold the symlinks
    my $config_dir = File::Spec->catdir($tempdir, 'config_root');
    my $collected  = File::Spec->catdir($config_dir, "collected");
    make_path($collected);

    my $target = Symlish::LinkTarget->new(
        key => 'one',
        entry => {
            target => $source_file, # absolute path to a single file
            paths  => [$collected],  # absolute dest for simplicity
        },
        config_dir => $config_dir,
    );

    ok($target->is_valid, 'is_valid for reverse-config target');
    is($target->path, $collected, 'path resolved to the collected/ dir');

    my @items = $target->items;
    is(scalar @items, 1, 'single item built');
    is($items[0]->source, $source_file, 'source is the absolute external path');
    is($items[0]->target, File::Spec->catfile($collected, 'one.conf'), 
        'target is collected/<basename>');
};

#=============================================================================
# Test: Reverse config - absolute glob spanning multiple files
#=============================================================================
subtest 'Reverse config: absolute glob target' => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    my $external_dir = File::Spec->catdir($tempdir, 'external');
    make_path($external_dir);
    write_file(File::Spec->catfile($external_dir, 'a.conf'), 'a');
    write_file(File::Spec->catfile($external_dir, 'b.conf'), 'b');
    write_file(File::Spec->catfile($external_dir, 'c.conf'), 'c');

    my $config_dir = File::Spec->catdir($tempdir, 'config_root');
    my $collected  = File::Spec->catdir($config_dir, 'collected');
    make_path($collected);

    my $target = Symlish::LinkTarget->new(
        key => 'glob',
        entry => {
            target => File::Spec->catfile($external_dir, '*'),
            paths  => [$collected],
        },
        config_dir => $config_dir,
    );

    my @items = $target->items;
    is(scalar @items, 3, 'three items built from glob');

    my %sources = map { $_->source => 1} @items;
    ok($sources{File::Spec->catfile($external_dir, 'a.conf')}, 'a.conf source');
    ok($sources{File::Spec->catfile($external_dir, 'b.conf')}, 'b.conf source');
    ok($sources{File::Spec->catfile($external_dir, 'c.conf')}, 'c.conf source');

    # Destination should be flat under $collected (no preserved subtree)
    my %dests = map { $_->target => 1} @items;
    ok($dests{File::Spec->catfile($collected, 'a.conf')}, 'a.conf target');
    ok($dests{File::Spec->catfile($collected, 'b.conf')}, 'b.conf target');
    ok($dests{File::Spec->catfile($collected, 'c.conf')}, 'c.conf target');
};

#=============================================================================
# Test: Reverse config - dotfile in absolute target
#=============================================================================
subtest 'Reverse config: dotfile included via absolute glob' => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    my $external_dir = File::Spec->catdir($tempdir, 'external');
    make_path($external_dir);

    write_file(File::Spec->catfile($external_dir, 'visible.txt'), 'v');
    write_file(File::Spec->catfile($external_dir, '.hidden'), 'h');

    my $config_dir = File::Spec->catdir($tempdir, 'config_root');
    my $collected  = File::Spec->catdir($config_dir, 'collected');
    make_path($collected);

    my $target = Symlish::LinkTarget->new(
        key => 'mix',
        entry => {
            target => File::Spec->catfile($external_dir, '*'),
            paths  => [$collected],
        },
        config_dir => $config_dir,
    );

    my @items = $target->items;
    my %sources = map { $_->source => 1 } @items;

    ok($sources{File::Spec->catfile($external_dir, 'visible.txt')}, 
        'visible file included');
    ok($sources{File::Spec->catfile($external_dir, '.hidden')}, 
        'dotfile included via absolute glob');
};

#=============================================================================
# Test: Reverse config - path relative to config_dir
#=============================================================================
subtest 'Reverse config - path relative to config_dir' => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    my $external_dir = File::Spec->catdir($tempdir, 'external');
    make_path($external_dir);
    write_file(File::Spec->catfile($external_dir, 'a.conf'), 'a');
    write_file(File::Spec->catfile($external_dir, 'b.conf'), 'b');

    my $config_dir = File::Spec->catdir($tempdir, 'config_root');
    my $collected  = File::Spec->catdir($config_dir, 'collected');
    make_path($collected);

    my $target = Symlish::LinkTarget->new(
        key => 'rel',
        entry => {
            target => File::Spec->catfile($external_dir, '*'),
            paths  => ['collected'], # relative, should resolve under $config_dir
        },
        config_dir => $config_dir,
    );

    ok($target->is_valid, 'is_valid for relative path resolved via config_dir');
    is($target->path, $collected, 'relative path anchored to config_dir');

    # Also test the full pipeline: items should reflect the resolved path,
    # so destinations need to land under $collected, not under CWD/collected.
    my @items = $target->items;
    is(scalar @items, 2, 'two items materialised via the relative path');
    
    my %dests = map { $_->target => 1 } @items;
    ok($dests{File::Spec->catfile($collected, 'a.conf')}, 
        'a.conf destination under collected/');
    ok($dests{File::Spec->catfile($collected, 'b.conf')}, 
        'b.conf destination under collected/');
};

done_testing();
