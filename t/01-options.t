#!/usr/bin/env perl
#
# 01-options.t - Tests for Symlish::Options module
#
# Tests command-line argument parsing and validation.

use strict;
use warnings;

use Test::More;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use lib "$RealBin/lib";

use File::Temp qw(tempdir);

use Symlish::Options qw(parse_command parse_directory parse_options);
use Symlish::Logger qw(trace);
use SymlishTest qw(capture);

#=============================================================================
# Test: parse_command - valid commands
#=============================================================================
subtest 'parse_command with valid commands' => sub {
    my @supported = qw(apply clean status);

    is(parse_command('apply', @supported), 'apply', 
        'Accepts apply command');
    is(parse_command('clean', @supported), 'clean', 
        'Accepts clean command');
    is(parse_command('status', @supported), 'status', 
        'Accepts status command');
};

#=============================================================================
# Test: parse_command - invalid commands
#=============================================================================
subtest 'parse_command with invalid command' => sub {
    my @supported = qw(apply clean status);
    
    eval { parse_command('invalid', @supported) };
    like($@, qr/Unknown command/, 'Dies on unknown command');
    
    # Note: empty string triggers help (exit 0), which we can't easily test
    # in a subtest without special handling. Skip this test.
};

#=============================================================================
# Test: parse_command - reject pre-1.1.0 command names
#=============================================================================
# Version 1.1.0 has changed the command names:
# link -> apply
# unlink -> clean
subtest 'parse_command rejects pre-1.1.0 command names' => sub {
    my @supported = qw(apply clean status);

    eval { parse_command('link', @supported) };
    like($@, qr/Unknown command/, "Old 'link' command rejected");

    eval { parse_command('unlink', @supported) };
    like($@, qr/Unknown command/, "Old 'unlink' command rejected");
};


#=============================================================================
# Test: parse_directory - valid directory
#=============================================================================
subtest 'parse_directory with valid directory' => sub {
    my $dir = tempdir(CLEANUP => 1);
    
    is(parse_directory($dir), $dir, 
        'Accepts existing directory');
};

#=============================================================================
# Test: parse_directory - missing argument
#=============================================================================
subtest 'parse_directory with missing argument' => sub {
    eval { parse_directory(undef) };
    like($@, qr/Missing.*directory/i, 'Dies when directory argument is missing');

    eval { parse_directory('') };
    like($@, qr/Missing.*directory/i, 'Dies when directory argument is empty');
};

#=============================================================================
# Test: parse_directory - non-existent directory
#=============================================================================
subtest 'parse_directory with non-existent directory' => sub {
    eval { parse_directory('/nonexistent/path/xyz123') };
    like($@, qr/not a valid directory/, 'Dies when directory does not exist');
};

#=============================================================================
# Test: parse_options - no options
#=============================================================================
subtest 'parse_options with no options' => sub {
    my @args = ();
    my %opts = parse_options(\@args);
    
    ok(!$opts{'dry-run'}, '--dry-run defaults to false');
    ok(!defined $opts{ignore}, '--ignore is not set');
    ok(!defined $opts{only}, '--only is not set');
    ok(!$opts{verbose}, '--verbose is not set');
    ok(!defined $opts{profile}, '--profile is not set');

    my $stdout = capture( sub { trace("Hello verbose"); });
    is($stdout, '', 'trace log not printed when --verbose is not set');
};


#=============================================================================
# Test: parse_options - die on unknown flags
#=============================================================================
subtest 'parse_options dies on unknown flags' => sub {
    my @args = ('--unknown-flag');

    my $stderr;
    {
        local *STDERR;
        open(STDERR, '>', \$stderr) or die "Cannot redirect STDERR: $!";
        eval { parse_options(\@args)};
    }

    ok($@, 'parse_options dies on unknown flag');
};

#=============================================================================
# Test: parse_options - dry-run flag
#=============================================================================
subtest 'parse_options with --dry-run' => sub {
    my @args = ('--dry-run');
    my %opts = parse_options(\@args);
    
    ok($opts{'dry-run'}, '--dry-run flag is set');
};

#=============================================================================
# Test: parse_options - ignore option
#=============================================================================
subtest 'parse_options with --ignore' => sub {
    my @args = ('--ignore', 'bash,git');
    my %opts = parse_options(\@args);
    
    is(ref($opts{ignore}), 'ARRAY', '--ignore value is an array');
    is_deeply($opts{ignore}, ['bash', 'git'], 
        '--ignore correctly parsed comma-separated values');
};

#=============================================================================
# Test: parse_options - only option
#=============================================================================
subtest 'parse_options with --only' => sub {
    my @args = ('--only', 'vscode,emacs');
    my %opts = parse_options(\@args);
    
    is(ref($opts{only}), 'ARRAY', '--only value is an array');
    is_deeply($opts{only}, ['vscode', 'emacs'], 
        '--only correctly parsed comma-separated values');
};

#=============================================================================
# Test: parse_options - ignore and only are mutually exclusive
#=============================================================================
subtest 'parse_options mutual exclusion' => sub {
    my @args = ('--ignore', 'bash', '--only', 'git');
    
    eval { parse_options(\@args) };
    like($@, qr/cannot be used together/, '--ignore and --only are mutually exclusive');
};

#=============================================================================
# Test: parse_options - handles whitespace in comma-separated values
#=============================================================================
subtest 'parse_options handles whitespace' => sub {
    my @args = ('--only', 'bash , git , vscode');
    my %opts = parse_options(\@args);
    
    is_deeply($opts{only}, ['bash', 'git', 'vscode'], 
        'Whitespace around commas is trimmed');
};

#=============================================================================
# Test: parse_options - verbose flag (long)
#=============================================================================
subtest 'parse_options - verbose flag (long)' => sub {
    my @args = ('--verbose');
    my %opts = parse_options(\@args);

    ok($opts{verbose}, '--verbose flag is set');

    my $stdout = capture(sub { trace("Hello verbose"); });
    like($stdout, qr/Hello verbose/, 'trace log is printed when --verbose is set');
};

#=============================================================================
# Test: parse_options - verbose flag (short)
#=============================================================================
subtest 'parse_options - verbose flag (short)' => sub {
    my @args = ('-v');
    my %opts = parse_options(\@args);

    ok($opts{verbose}, '-v flag is set');

    my $stdout = capture(sub { trace("Hello verbose"); });
    like($stdout, qr/Hello verbose/, 'trace log is printed when -v is set');
};

#=============================================================================
# Test: parse_options - profile option
#=============================================================================
subtest 'parse_options - profile option' => sub {
    my @args = ('--profile', 'global');
    my %opts = parse_options(\@args);

    is($opts{profile}, 'global', 'Profile correctly extracted');
};

done_testing();
