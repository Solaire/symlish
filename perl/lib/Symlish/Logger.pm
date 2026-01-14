package Symlish::Logger;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(format_line reset bold red green yellow blue magenta cyan white gray);

# Format line with indentation
sub format_line {
    my ($indent, $text) = @_;
    return sprintf("%-*s", $indent, '') . $text . "\n";
}

# ANSI foreground colour codes
sub reset  { "\e[0m" }
sub bold   { "\e[1m$_[0]\e[0m" }

sub red    { "\e[31m$_[0]\e[0m" }
sub green  { "\e[32m$_[0]\e[0m" }
sub yellow { "\e[33m$_[0]\e[0m" }
sub blue   { "\e[34m$_[0]\e[0m" }
sub magenta{ "\e[35m$_[0]\e[0m" }
sub cyan   { "\e[36m$_[0]\e[0m" }
sub white  { "\e[97m$_[0]\e[0m" }
sub gray   { "\e[90m$_[0]\e[0m" }

sub bright_red    { "\e[91m$_[0]\e[0m" }
sub bright_green  { "\e[92m$_[0]\e[0m" }
sub bright_yellow { "\e[93m$_[0]\e[0m" }
sub bright_blue   { "\e[94m$_[0]\e[0m" }
sub bright_magenta{ "\e[95m$_[0]\e[0m" }
sub bright_cyan   { "\e[96m$_[0]\e[0m" }
sub bright_white  { "\e[97m$_[0]\e[0m" }

1;