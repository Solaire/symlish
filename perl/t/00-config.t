#!/usr/bin/env perl
#
# 00-config.t - Tests for Symlish::Config module
#
# Tests configuration loading, YAML parsing, and validation logic.

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
        'Dies when symlish.conf.yaml is missing';
};

#=============================================================================
# Test: Valid minimal configuration
#=============================================================================
subtest 'Valid minimal config' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  bash:
    target: bash/*
    paths:
      - ~/
YAML

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
    _write_yaml($dir, <<'YAML');
link:
  bash:
    target: bash/*
    paths:
      - ~/
  vscode:
    target: vscode/**
    paths:
      - ~/.config/Code/
  git:
    target: git/*
    ignore: true
    paths:
      - ~/
YAML

    my $config = load_config($dir);
    
    is(scalar keys %{$config->{link}}, 3, 'All three entries loaded');
    ok(exists $config->{link}{bash}, 'bash entry exists');
    ok(exists $config->{link}{vscode}, 'vscode entry exists');
    ok(exists $config->{link}{git}, 'git entry exists');
    # YAML::PP converts 'true' to 1, so check for truthy value
    ok($config->{link}{git}{ignore}, 'ignore flag is truthy');
};

#=============================================================================
# Test: Invalid YAML syntax
#=============================================================================
subtest 'Invalid YAML syntax' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  bash:
    target: bash/*
    paths:
  - invalid indentation here
YAML

    throws_ok { load_config($dir) }
        qr/Yaml syntax|ERROR/i,
        'Dies on invalid YAML syntax';
};

#=============================================================================
# Test: Missing 'link' block
#=============================================================================
subtest 'Missing link block' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
other_key:
  something: value
YAML

    throws_ok { load_config($dir) }
        qr/'link' block is missing/,
        'Dies when link block is missing';
};

#=============================================================================
# Test: link is not a hash
#=============================================================================
subtest 'link is not a hash' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  - item1
  - item2
YAML

    throws_ok { load_config($dir) }
        qr/'link' must be a hash/,
        'Dies when link is an array instead of hash';
};

#=============================================================================
# Test: Entry missing 'paths'
#=============================================================================
subtest 'Entry missing paths' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  bash:
    target: bash/*
YAML

    throws_ok { load_config($dir) }
        qr/missing 'paths'/,
        'Dies when entry is missing paths';
};

#=============================================================================
# Test: Entry missing 'target'
#=============================================================================
subtest 'Entry missing target' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  bash:
    paths:
      - ~/
YAML

    throws_ok { load_config($dir) }
        qr/missing 'target'/,
        'Dies when entry is missing target';
};

#=============================================================================
# Test: paths is not an array
#=============================================================================
subtest 'paths is not an array' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  bash:
    target: bash/*
    paths: ~/
YAML

    throws_ok { load_config($dir) }
        qr/'paths' must be an array/,
        'Dies when paths is a string instead of array';
};

#=============================================================================
# Test: Invalid conflict value
#=============================================================================
subtest 'Invalid conflict value' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  bash:
    target: bash/*
    conflict: invalid_value
    paths:
      - ~/
YAML

    throws_ok { load_config($dir) }
        qr/Invalid 'conflict' value/,
        'Dies on invalid conflict value';
};

#=============================================================================
# Test: Valid conflict values
#=============================================================================
subtest 'Valid conflict values' => sub {
    my $dir = tempdir(CLEANUP => 1);
    _write_yaml($dir, <<'YAML');
link:
  bash:
    target: bash/*
    conflict: skip
    paths:
      - ~/
  git:
    target: git/*
    conflict: overwrite
    paths:
      - ~/
YAML

    lives_ok { load_config($dir) }
        'Accepts valid conflict values (skip, overwrite)';
};

#=============================================================================
# Test: Boolean validation for ignore
#=============================================================================
subtest 'Boolean validation for ignore' => sub {
    my $dir = tempdir(CLEANUP => 1);
    
    # Valid boolean values
    for my $val (qw(true false 0 1 True FALSE)) {
        _write_yaml($dir, <<"YAML");
link:
  bash:
    target: bash/*
    ignore: $val
    paths:
      - ~/
YAML
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
        _write_yaml($dir, <<"YAML");
link:
  bash:
    target: bash/*
    ignore-empty: $val
    paths:
      - ~/
YAML
        lives_ok { load_config($dir) }
            "Accepts ignore-empty: $val as valid boolean";
    }
};

#=============================================================================
# Helper: Write YAML config file
#=============================================================================
sub _write_yaml {
    my ($dir, $content) = @_;
    my $file = File::Spec->catfile($dir, 'symlish.conf.yaml');
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh $content;
    close $fh;
}

done_testing();
