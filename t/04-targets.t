#!/usr/bin/env perl
#
# 04-targets.t - Tests for Symlish::Targets module
#
# Tests target building and filtering from configuration.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Symlish::Targets qw(build_targets filter_targets);

#=============================================================================
# Test: build_targets creates LinkTarget objects
#=============================================================================
subtest 'build_targets' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    
    # Create destination directory
    my $dest = File::Spec->catdir($tempdir, 'dest');
    make_path($dest);
    
    my $config_ref = {
        config_dir => $tempdir,
        link => {
            bash => {
                target => 'bash/*',
                paths => [$dest],
            },
            git => {
                target => 'git/*',
                paths => [$dest],
            },
        },
    };
    
    my @targets = build_targets($config_ref);
    
    is(scalar(@targets), 2, 'Two targets created');
    
    # Get keys
    my %keys = map { $_->key => 1 } @targets;
    ok($keys{bash}, 'bash target created');
    ok($keys{git}, 'git target created');
};

#=============================================================================
# Test: filter_targets with --only
#=============================================================================
subtest 'filter_targets with --only' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest = File::Spec->catdir($tempdir, 'dest');
    make_path($dest);
    
    my $config_ref = {
        config_dir => $tempdir,
        link => {
            bash => { target => 'bash/*', paths => [$dest] },
            git => { target => 'git/*', paths => [$dest] },
            vscode => { target => 'vscode/*', paths => [$dest] },
        },
    };
    
    my @targets = build_targets($config_ref);
    
    my $options = { only => ['bash', 'git'] };
    my @filtered = filter_targets(\@targets, $options);
    
    is(scalar(@filtered), 2, 'Filtered to 2 targets');
    
    my %keys = map { $_->key => 1 } @filtered;
    ok($keys{bash}, 'bash included');
    ok($keys{git}, 'git included');
    ok(!$keys{vscode}, 'vscode excluded');
};

#=============================================================================
# Test: filter_targets with --ignore
#=============================================================================
subtest 'filter_targets with --ignore' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest = File::Spec->catdir($tempdir, 'dest');
    make_path($dest);
    
    my $config_ref = {
        config_dir => $tempdir,
        link => {
            bash => { target => 'bash/*', paths => [$dest] },
            git => { target => 'git/*', paths => [$dest] },
            vscode => { target => 'vscode/*', paths => [$dest] },
        },
    };
    
    my @targets = build_targets($config_ref);
    
    my $options = { ignore => ['vscode'] };
    my @filtered = filter_targets(\@targets, $options);
    
    is(scalar(@filtered), 2, 'Filtered to 2 targets');
    
    my %keys = map { $_->key => 1 } @filtered;
    ok($keys{bash}, 'bash included');
    ok($keys{git}, 'git included');
    ok(!$keys{vscode}, 'vscode ignored');
};

#=============================================================================
# Test: filter_targets with no filter
#=============================================================================
subtest 'filter_targets with no filter' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $dest = File::Spec->catdir($tempdir, 'dest');
    make_path($dest);
    
    my $config_ref = {
        config_dir => $tempdir,
        link => {
            bash => { target => 'bash/*', paths => [$dest] },
            git => { target => 'git/*', paths => [$dest] },
        },
    };
    
    my @targets = build_targets($config_ref);
    
    my $options = {};
    my @filtered = filter_targets(\@targets, $options);
    
    is(scalar(@filtered), 2, 'All targets returned when no filter');
};

done_testing();
