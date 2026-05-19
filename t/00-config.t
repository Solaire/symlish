#!/usr/bin/env perl
#
# 00-config.t - Tests for Symlish::Config module
#
# Tests configuration loading, INI parsing, and validation logic.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use lib "$RealBin/lib";

use Symlish::Config qw(load_config);
use SymlishTest qw(capture_warnings);

# Create a temporary test directory
my $tempdir = tempdir(CLEANUP => 1);

#=============================================================================
# Test: Missing config file
#=============================================================================
subtest 'Missing config file' => sub {
    eval { load_config($tempdir) };
    like($@, qr/not found/, 'Dies when symlish.conf.ini is missing');
};

#=============================================================================
# Legacy config tests
#=============================================================================
# There test the pre-1.1.0 layout where the file is a flat list of 
# [entry] headers with no [[profile]] wrapper. Symlish wraps legacy config in
# an implicit 'default' profile to ensure backwards compatibility.
#=============================================================================

#=============================================================================
# Test: Legacy - Valid minimal configuration
#=============================================================================
subtest 'Legacy: Valid minimal config' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
paths = ~/
INI

    my $config = load_config($dir);

    ok(defined $config, 'Config loaded successfully');
    is(ref($config), 'HASH', 'Config is a hash ref');
    ok(exists $config->{profiles}, 'Config has profiles key');
    ok(exists $config->{profiles}{default}{bash}, 'Default profile has bash entry');
    is($config->{profiles}{default}{bash}{target}, 'bash/*', 'Target pattern is correct');
    ok(defined $config->{path}, '"path" field is set');
    ok(defined $config->{dir}, '"dir" field is set');
};

#=============================================================================
# Test: Legacy - Multiple entries
#=============================================================================
subtest 'Legacy: Multiple config entries' => sub {
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

    is(scalar keys %{$config->{profiles}}, 1, '1 profile loaded');
    is((keys %{$config->{profiles}})[0], 'default', 'Single profile implicitly names "default"');
    ok(exists $config->{profiles}{default}{bash},   'bash entry exists');
    ok(exists $config->{profiles}{default}{vscode}, 'vscode entry exists');
    ok(exists $config->{profiles}{default}{git},    'git entry exists');
    ok($config->{profiles}{default}{git}{ignore}, 'ignore flag is truthy');
};

#=============================================================================
# Multi-config tests
#=============================================================================
# From version 1.1.0, [[profile]] headers can be used as a wrapper around [entry]
# headers, letting one file host several independent profiles (personal, work, etc.)
# build_target() takes a profile name and returns only the entries below it.
#=============================================================================

#=============================================================================
# Test: Multi-config - single top-level profile
#=============================================================================
subtest 'Multi: single top-level profile' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[[personal]]

[bash]
target = bash/*
paths = ~/

[git]
target = git/*
paths = ~/
INI

    my $config = load_config($dir);

    is(scalar keys %{$config->{profiles}}, 1, 'one top-level profile parsed');
    ok(!exists $config->{profiles}{default}, 'no implicit default profile');

    ok(exists $config->{profiles}{personal}, 'personal profile present');
    ok(exists $config->{profiles}{personal}{git}, 'git entry under personal');
    ok(exists $config->{profiles}{personal}{bash}, 'bash entry under personal');
};

#=============================================================================
# Test: Multi-config - multiple top-level profiles
#=============================================================================
subtest 'Multi: multiple top-level profiles' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[[personal]]

[bash]
target = bash/*
paths = ~/

[[work]]

[git]
target = git/*
paths = ~/
INI

    my $config = load_config($dir);

    is(scalar keys %{$config->{profiles}}, 2, 'two top-level profile parsed');

    ok(exists $config->{profiles}{personal}, 'personal profile present');
    ok(exists $config->{profiles}{personal}{bash}, 'bash entry under personal');
    ok(!exists $config->{profiles}{personal}{git}, 'git does not leak into personal');

    ok(exists $config->{profiles}{work}, 'work profile present');
    ok(exists $config->{profiles}{work}{git}, 'git entry under work');
    ok(!exists $config->{profiles}{work}{bash}, 'bash does not leak into personal');
};

#=============================================================================
# Test: Multi-config - entry-level validation still applies
#=============================================================================
# Every entry under a [[profile]] should be validated the same as a legacy
# entry; missing 'paths', invalid 'conflict', etc. all still die.
subtest 'Multi: entry-level validation still applies' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[[personal]]

[bash]
target = bash/*
INI

    eval { load_config($dir) };
    like($@, qr/missing 'paths'/, 'Missing paths under [[profile]] still dies');
};

#=============================================================================
# Test: Multi-config - empty [[profile]] with no entries
#=============================================================================
# Empty [[profile]] header with no [entry] headers will parse without
# error and produce an empty profile. Emits a warning via Logger::warning but
# does not die.
subtest 'Multi: empty profile is accepted with warning' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[[personal]]
INI

    my $config;
    my $warnings = capture_warnings(sub { eval { $config = load_config($dir) }; });
    
    ok(!$@, 'Empty [[profile]] does not die') or diag $@;
    ok(exists $config->{profiles}{personal}, 'personal profile is present');
    is(scalar keys %{$config->{profiles}{personal}}, 0, 'personal has no entries');
    ok(scalar(grep { /'personal' has no elements/ } @$warnings), 'A "no elements" warning is emitted');
};

#=============================================================================
# Mixed-config tests
#=============================================================================
# Mixed config has at least one bare [entry] BEFORE any [[profile]] header
# (triggering an implicit 'default' profile) AND at least one [[profile]]
# header. Should not be allowed.
#=============================================================================

#=============================================================================
# Test: Mixed - bare [entry] before explicit [[profile]]
#=============================================================================
subtest 'Mixed: bare [entry] then [[profile]] is rejected' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
paths = ~/

[[personal]]

[git]
target = git/*
paths = ~/
INI

    eval { load_config($dir) };
    like($@, qr/implicit and explicit profiles cannot be used together/i, 
        'Mixed layout dies with the right message');
};

#=============================================================================
# General tests
#=============================================================================
# General config validation tests. the rules ar the same for legacy and mixed
# config types.
#=============================================================================

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

    eval { load_config($dir) };
    like($@, qr/Unrecognized line/i, 'Dies on unrecognized INI syntax');
};

#=============================================================================
# Test: Empty config (no entries)
#=============================================================================
subtest 'Empty config' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
; Just a comment, no entries
INI

    eval { load_config($dir) };
    like($@, qr/ERROR: Invalid config; most likely empty/, 'Dies when config has no entries');
};

#=============================================================================
# Test: Key outside any entry
#=============================================================================
subtest 'Key outside any entry' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_ini($dir, <<'INI');
orphan_key = some_value

[bash]
target = bash/*
paths = ~/
INI

    eval { load_config($dir) };
    like($@, qr/orphaned key 'orphan_key'/, 'Dies when key appears before any [entry] header');
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

    eval { load_config($dir) };
    like($@, qr/missing 'paths'/, 'Dies when entry is missing paths');
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

    eval { load_config($dir) };
    like($@, qr/missing 'target'/, 'Dies when entry is missing target');
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
    my $paths = $config->{profiles}{default}{vscode}{paths};

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

    eval { load_config($dir) };
    like($@, qr/Invalid 'conflict' value/, 'Dies on invalid conflict value');
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

    eval { load_config($dir) };
    ok(!$@, 'Accepts valid conflict values (skip, overwrite)') or diag $@;
};

#=============================================================================
# Test: Boolean validation for ignore
#=============================================================================
subtest 'Boolean validation for ignore' => sub {
    my $dir = tempdir(CLEANUP => 1);

    # Parser stores the raw string
    # _to_bool in LinkTarget does the actual true/false interpolation later.
    for my $val (qw(true false 0 1 True FALSE)) {
        _write_ini($dir, <<"INI");
[bash]
target = bash/*
ignore = $val
paths = ~/
INI

        my $config = eval { load_config($dir) };
        ok(!$@, "Accepts ignore: $val as valid boolean") or diag $@;
        is($config->{profiles}{default}{bash}{ignore}, $val, "ignore: $val stored as-is");
    }
};

#=============================================================================
# Test: Boolean validation for ignore-empty
#=============================================================================
subtest 'Boolean validation for ignore-empty' => sub {
    my $dir = tempdir(CLEANUP => 1);

    # Parser stores the raw string
    # _to_bool in LinkTarget does the actual true/false interpolation later.
    for my $val (qw(true false 0 1)) {
        _write_ini($dir, <<"INI");
[bash]
target = bash/*
ignore-empty = $val
paths = ~/
INI

        my $config = eval { load_config($dir) };
        ok(!$@, "Accepts ignore-empty: $val as valid boolean") or diag $@;
        is($config->{profiles}{default}{bash}{'ignore-empty'}, $val, "ignore-empty: $val stored as-is");
    }
};

#=============================================================================
# Test: Empty 'paths' is rejected
#=============================================================================
subtest 'empty "paths" is rejected' => sub {
    my $dir = tempdir(CLEANUP => 1);

    # No value at all
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
paths = 
INI

    eval { load_config($dir) };
    like($@, qr/'paths' must contain at least one value/, "Dies when 'paths' has no value");
};

#=============================================================================
# Test: Empty elements in 'paths' is rejected
#=============================================================================
subtest 'empty element "paths" is rejected' => sub {
    my $dir = tempdir(CLEANUP => 1);

    # No value at all
    _write_ini($dir, <<'INI');
[bash]
target = bash/*
paths = ~/, , ~/.config/
INI

    eval { load_config($dir) };
    like($@, qr/'paths' contains an empty value/, "Dies when 'paths' comma list contains an empty entry");
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
; inline entry comment
target = bash/*

paths = ~/
INI

    eval { load_config($dir) };
    ok(!$@, 'Config with comments and blank lines loads without error') or diag $@;
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

