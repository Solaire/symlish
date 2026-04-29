#!/usr/bin/env perl
#
# 06-logger.t - Tests for Symlish::Logger module
#
# Tests ANSI color formatting and text utilities.

use strict;
use warnings;

use Test::More;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Symlish::Logger qw(format_line reset bold red green yellow blue magenta cyan white gray);

#=============================================================================
# Test: format_line basic functionality
#=============================================================================
subtest 'format_line' => sub {
    my $result = format_line(0, 'Hello');
    is($result, "Hello\n", 'format_line with 0 indent');
    
    $result = format_line(2, 'Indented');
    is($result, "  Indented\n", 'format_line with 2 space indent');
    
    $result = format_line(4, 'More indent');
    is($result, "    More indent\n", 'format_line with 4 space indent');
};

#=============================================================================
# Test: Color functions return ANSI codes
#=============================================================================
subtest 'Color functions' => sub {
    # Each color should wrap text in escape codes
    like(red('text'), qr/\e\[31m.*\e\[0m/, 'red wraps in ANSI codes');
    like(green('text'), qr/\e\[32m.*\e\[0m/, 'green wraps in ANSI codes');
    like(yellow('text'), qr/\e\[33m.*\e\[0m/, 'yellow wraps in ANSI codes');
    like(blue('text'), qr/\e\[34m.*\e\[0m/, 'blue wraps in ANSI codes');
    like(magenta('text'), qr/\e\[35m.*\e\[0m/, 'magenta wraps in ANSI codes');
    like(cyan('text'), qr/\e\[36m.*\e\[0m/, 'cyan wraps in ANSI codes');
    like(white('text'), qr/\e\[37m.*\e\[0m/, 'white wraps in ANSI codes');
    like(gray('text'), qr/\e\[90m.*\e\[0m/, 'gray wraps in ANSI codes');
};

#=============================================================================
# Test: bold function
#=============================================================================
subtest 'bold function' => sub {
    like(bold('text'), qr/\e\[1m.*\e\[0m/, 'bold wraps in ANSI codes');
};

#=============================================================================
# Test: reset function
#=============================================================================
subtest 'reset function' => sub {
    is(reset(), "\e[0m", 'reset returns ANSI reset code');
};

#=============================================================================
# Test: Color functions preserve text
#=============================================================================
subtest 'Colors preserve text' => sub {
    like(red('Hello World'), qr/Hello World/, 'red preserves text');
    like(green('Test 123'), qr/Test 123/, 'green preserves text');
};

done_testing();
