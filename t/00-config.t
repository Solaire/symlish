#!/usr/bin/env perl
#
# 00-config.t - Tests for Symlish::Config module
#
# Tests configuration loading, INI parsing, and validation logic.

use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Symlish::Config qw(load_config);

# Create a temporary test directory
my $tempdir = tempdir(CLEANUP => 1);

#=============================================================================
# Test: Missing config file
#=============================================================================
subtest 'Missing config file' => sub {
    throws_ok { load_config($tempdir) }
        qr/not found/,
        'Dies when symlish.conf.ini is missing';
};

#=============================================================================
# Test: Valid minimal configuration
#=============================================================================
subtest 'Valid minimal config' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
paths = ~/
INI

    my $config = load_config($dir);

    ok(defined $config, 'Config loaded successfully');
    is(ref($config), 'HASH', 'Config is a hash ref');
    ok(exists $config->{link}, 'Config has link key');
    ok(exists $config->{link}{bash}, 'Config has bash entry');
    is($config->{link}{bash}{target}, 'bash/*', 'Target pattern is correct');
    ok(defined $config->{config_path}, 'config_path is set');
    ok(defined $config->{config_dir}, 'config_dir is set');
};

#=============================================================================
# Test: Multiple entries
#=============================================================================
subtest 'Multiple config entries' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
paths = ~/

[vscode]
target = vscode/**
paths = ~/.config/Code/

[git]
target = git/*
ignore = true
paths = ~/
INI

    my $config = load_config($dir);

    is(scalar keys %{$config->{link}}, 3, 'All three entries loaded');
    ok(exists $config->{link}{bash},   'bash entry exists');
    ok(exists $config->{link}{vscode}, 'vscode entry exists');
    ok(exists $config->{link}{git},    'git entry exists');
    ok($config->{link}{git}{ignore}, 'ignore flag is truthy');
};

#=============================================================================
# Test: Invalid INI syntax (unrecognized line)
#=============================================================================
subtest 'Invalid INI syntax' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
this is not valid ini syntax
paths = ~/
INI

    throws_ok { load_config($dir) }
        qr/Unrecognized line/i,
        'Dies on unrecognized INI syntax';
};

#=============================================================================
# Test: Empty config (no sections)
#=============================================================================
subtest 'Empty config' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
; Just a comment, no sections
INI

    throws_ok { load_config($dir) }
        qr/no target sections defined/,
        'Dies when config has no sections';
};

#=============================================================================
# Test: Key outside a section
#=============================================================================
subtest 'Key outside a section' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
orphan_key = some_value

[bash]
target = bash/*
paths = ~/
INI

    throws_ok { load_config($dir) }
        qr/outside of a section/,
        'Dies when key appears before any section header';
};

#=============================================================================
# Test: Entry missing 'paths'
#=============================================================================
subtest 'Entry missing paths' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
INI

    throws_ok { load_config($dir) }
        qr/missing 'paths'/,
        'Dies when entry is missing paths';
};

#=============================================================================
# Test: Entry missing 'target'
#=============================================================================
subtest 'Entry missing target' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
paths = ~/
INI

    throws_ok { load_config($dir) }
        qr/missing 'target'/,
        'Dies when entry is missing target';
};

#=============================================================================
# Test: Paths are parsed as array
#=============================================================================
subtest 'Paths are parsed as an array' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[vscode]
target = vscode/*
paths = $APPDATA/Code/, ~/.config/Code/
INI

    my $config = load_config($dir);
    my $paths = $config->{link}{vscode}{paths};

    is(ref($paths), 'ARRAY', 'paths is an array ref');
    is(scalar @$paths, 2,    'paths has two entries');
    is($paths->[0], '$APPDATA/Code/',  'first path correct');
    is($paths->[1], '~/.config/Code/', 'second path correct');
};

#=============================================================================
# Test: Invalid conflict value
#=============================================================================
subtest 'Invalid conflict value' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
conflict = invalid_value
paths = ~/
INI

    throws_ok { load_config($dir) }
        qr/Invalid 'conflict' value/,
        'Dies on invalid conflict value';
};

#=============================================================================
# Test: Valid conflict values
#=============================================================================
subtest 'Valid conflict values' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
conflict = skip
paths = ~/

[git]
target = git/*
conflict = overwrite
paths = ~/
INI

    lives_ok { load_config($dir) }
        'Accepts valid conflict values (skip, overwrite)';
};

#=============================================================================
# Test: Boolean validation for ignore
#=============================================================================
subtest 'Boolean validation for ignore' => sub {
    my $dir = tempdir(CLEANUP => 1);

    for my $val (qw(true false 0 1 True FALSE)) {
        _write_ini($dir, <<"INI");
[bash]
target = bash/*
ignore = $val
paths = ~/
INI
        lives_ok { load_config($dir) }
            "Accepts ignore: $val as valid boolean";
    }
};

#=============================================================================
# Test: Boolean validation for ignore-empty
#=============================================================================
subtest 'Boolean validation for ignore-empty' => sub {
    my $dir = tempdir(CLEANUP => 1);

    for my $val (qw(true false 0 1)) {
        _write_ini($dir, <<"INI");
[bash]
target = bash/*
ignore-empty = $val
paths = ~/
INI
        lives_ok { load_config($dir) }
            "Accepts ignore-empty: $val as valid boolean";
    }
};

#=============================================================================
# Test: Comments and blank lines are ignored
#=============================================================================
subtest 'Comments and blank lines are ignored' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
; This is a semicolon comment
# This is a hash comment

[bash]
; inline section comment
target = bash/*

paths = ~/
INI

    lives_ok { load_config($dir) }
        'Config with comments and blank lines loads without error';
};

#=============================================================================
# Helper: Write INI config file
#=============================================================================
sub _write_ini {
    my ($dir, $content) = @_;
    my $file = File::Spec->catfile($dir, 'symlish.conf.ini');
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh $content;
    close $fh;
}

done_testing();

