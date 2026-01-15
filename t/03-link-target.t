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

use Symlish::LinkTarget;

#=============================================================================
# Test: Constructor creates object
#=============================================================================
subtest 'Constructor' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest_dir = File::Spec->catdir($tempdir, 'dest');
    my $src_dir = File::Spec->catdir($tempdir, 'bash');
    
    make_path($dest_dir);
    make_path($src_dir);
    _write_file(File::Spec->catfile($src_dir, '.bashrc'), 'test');
    
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
    _write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');
    
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
    _write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');
    
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
subtest 'Tilde expansion' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $src_dir = File::Spec->catdir($tempdir, 'test');
    make_path($src_dir);
    _write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');
    
    my $target = Symlish::LinkTarget->new(
        key => 'test',
        entry => {
            target => 'test/*',
            paths => ['~'],  # Home directory
        },
        config_dir => $tempdir,
    );
    
    is($target->path, $ENV{HOME}, 'Tilde expanded to HOME');
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
    _write_file(File::Spec->catfile($src_dir, '.bashrc'), 'bashrc');
    _write_file(File::Spec->catfile($src_dir, '.bash_profile'), 'profile');
    _write_file(File::Spec->catfile($src_dir, 'visible.txt'), 'visible');
    
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
    _write_file(File::Spec->catfile($src_dir, '.bashrc'), 'bashrc');
    _write_file(File::Spec->catfile($src_dir, '.profile'), 'profile');
    
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
    _write_file(File::Spec->catfile($src_dir, 'file.txt'), 'test');
    
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
# Helper
#=============================================================================
sub _write_file {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print $fh $content;
    close $fh;
}

done_testing();
