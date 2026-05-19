#!/usr/bin/env perl
#
# 06-logger.t - Tests for Symlish::Logger module
#
# Tests ANSI colour formatting and text utilities.

use strict;
use warnings;

use Test::More;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use lib "$RealBin/lib";

use Symlish::Logger qw(set_verbose info warning trace);
use SymlishTest qw(capture capture_warnings);

#=============================================================================
# Test: Verbose logging
#=============================================================================
subtest 'Verbose logging' => sub {
    # Verbose logging off by default
    my $stdout = capture( sub { trace ("Off by default"); });
    is($stdout, '', 'no trace log emitted');

    # Enable verbose logging
    set_verbose(1);
    $stdout = capture( sub { trace("Verbose enabled"); });
    like($stdout, qr/Verbose enabled/, 'trace log emitted to STDOUT');
    like($stdout, qr/\e\[90m.*\e\[0m/, 'trace log is wrapped in ANSI codes');

    # Disable verbose logging
    set_verbose(0);
    $stdout = capture( sub { trace ("Verbose disabled"); });
    is($stdout, '', 'no trace log emitted after disabling verbose logger');
};

#=============================================================================
# Test: Verbose logging - Indentation
#=============================================================================
subtest 'Verbose logging - Indentation' => sub {
    set_verbose(1);

    my $stdout = capture( sub { trace ('Hello', 0); });
    like($stdout, qr/Hello/, 'trace log with 0 indent');
    
    $stdout = capture( sub { trace ('Indented', 2); });
    like($stdout, qr/\s{2}Indented/, 'trace log with 2 space indent');
    
    $stdout = capture( sub { trace ('More indent', 4); });
    like($stdout, qr/\s{4}More indent/, 'trace log with 4 space indent');
};

#=============================================================================
# Test: Warning logging
#=============================================================================
subtest 'Warning logging' => sub {
    my $w = capture_warnings( sub { warning ('Hello', 0); });
    is(scalar @$w, 1, 'exactly one warning emitted');
    like($w->[0], qr/Hello/, 'warning log with 0 indent');
    like($w->[0], qr/\e\[31m.*\e\[0m/, 'warning log is wrapped in ANSI codes');

    $w = capture_warnings( sub { warning ('Indented', 2); });
    like($w->[0], qr/\s{2}Indented/, 'warning log with 2 space indent');
    
    $w = capture_warnings( sub { warning ('More indent', 4); });
    like($w->[0], qr/\s{4}More indent/, 'warning log with 4 space indent');
};

#=============================================================================
# Test: Info logging - Colours
#=============================================================================
subtest 'Info logging - Colours' => sub {
    my $stdout = capture( sub { info('text'); });
    like($stdout, qr/\e\[0m.*\e\[0m/, 'Default colour is reset');

    $stdout = capture( sub { info('text', 'invalid'); });
    like($stdout, qr/\e\[0m.*\e\[0m/, 'invalid colour resolves to reset');

    # Each colour should wrap text in escape codes
    $stdout = capture( sub { info('text', 'red'); });
    like($stdout, qr/\e\[31m.*\e\[0m/, 'red wraps in ANSI codes');

    $stdout = capture( sub { info('text', 'green'); });
    like($stdout, qr/\e\[32m.*\e\[0m/, 'green wraps in ANSI codes');

    $stdout = capture( sub { info('text', 'yellow'); });
    like($stdout, qr/\e\[33m.*\e\[0m/, 'yellow wraps in ANSI codes');

    $stdout = capture( sub { info('text', 'blue'); });
    like($stdout, qr/\e\[34m.*\e\[0m/, 'blue wraps in ANSI codes');

    $stdout = capture( sub { info('text', 'magenta'); });
    like($stdout, qr/\e\[35m.*\e\[0m/, 'magenta wraps in ANSI codes');

    $stdout = capture( sub { info('text', 'cyan'); });
    like($stdout, qr/\e\[36m.*\e\[0m/, 'cyan wraps in ANSI codes');

    $stdout = capture( sub { info('text', 'white'); });
    like($stdout, qr/\e\[37m.*\e\[0m/, 'white wraps in ANSI codes');

    $stdout = capture( sub { info('text', 'gray'); });
    like($stdout, qr/\e\[90m.*\e\[0m/, 'gray wraps in ANSI codes');
};

#=============================================================================
# Test: Info logging - Indentation
#=============================================================================
subtest 'Info logging - Indentation' => sub {
    my $stdout = capture( sub { info ('Hello', 'white', 0); });
    like($stdout, qr/Hello/, 'info log with 0 indent');
    
    $stdout = capture( sub { info ('Indented', 'white', 2); });
    like($stdout, qr/\s{2}Indented/, 'info log with 2 space indent');
    
    $stdout = capture( sub { info ('More indent', 'white', 4); });
    like($stdout, qr/\s{4}More indent/, 'info log with 4 space indent');
};

#=============================================================================
# Test: ANSI colours preserve text
#=============================================================================
subtest 'ANSI colours preserve text' => sub {
    my $stdout = capture( sub { info ('Hello', 'green', 0); });
    like($stdout, qr/Hello/, 'green preserves text');
};

done_testing();
