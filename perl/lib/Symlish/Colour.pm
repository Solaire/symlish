package Symlish::Colour;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(reset bold red green yellow blue magenta cyan white gray);

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

1;