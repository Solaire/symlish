package Symlish::Logger;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(set_verbose info warning trace);

# Symlish::Logger - Logging primitives for the CLI.
# Public API:
#   info($msg, $colour, $indent) - coloured, indented print to STDOUT
#   warning($msg, $indent)       - red warn() to STDERR
#   trace($msg, $indent)         - grey print to STDOUT, gated on $verbose
#   set_verbose($bool)           - toggle trace output
# %colours and format_line are package-private helpers.

my $verbose = 0;

# Dispatch table of ANSI colour wrappers. Each value is a coderef that takes
# a string and returns it wrapped in the relevant escape codes plus a reset.
my %colours = (
    'reset'   => sub { "\e[0m$_[0]\e[0m" },
    'red'     => sub { "\e[31m$_[0]\e[0m" },
    'green'   => sub { "\e[32m$_[0]\e[0m" },
    'yellow'  => sub { "\e[33m$_[0]\e[0m" },
    'blue'    => sub { "\e[34m$_[0]\e[0m" },
    'magenta' => sub { "\e[35m$_[0]\e[0m" },
    'cyan'    => sub { "\e[36m$_[0]\e[0m" },
    'white'   => sub { "\e[37m$_[0]\e[0m" },
    'gray'    => sub { "\e[90m$_[0]\e[0m" },
    'grey'    => sub { "\e[90m$_[0]\e[0m" },
);

# set_verbose($bool) - Toggle verbose logging
# Params:
#   $bool - boolean verbose switch
sub set_verbose {
    $verbose = $_[0];
}

# format_line($indent, $text) - Prepends $indent spaces to $text.
# Note: no trailing newline is appended, callers add it after wrapping in 
# colour codes.
# Params:
#   $indent - Number of spaces to prepend
#   $text   - The text to format
# Returns: Indented text
sub format_line {
    my ($indent, $text) = @_;
    return sprintf("%-*s", $indent, '') . $text;
}

# info($msg, $colour, $indent) - Prints a coloured, indented message to STDOUT
# Unknown or undefined $colour defaults to 'reset'.
# Params:
#   $msg    - Log message
#   $colour - Key from %colours (e.g. 'red, 'green'); defaults to 'reset'
#             if missing or unknown.
#   $indent - Number of spaces to prepend (defaults to 0).
sub info {
    my ($msg, $colour, $indent) = @_;
    $colour = "reset"
        unless defined $colour && defined $colours{$colour};
    $indent //= 0;

    print $colours{$colour}->(format_line($indent, $msg)) . "\n";
}

# warning($msg, $indent) - Print warning log to STDERR
# Params:
#   $msg    - Log message
#   $indent - Number of spaces to prepend (defaults to 0).
sub warning {
    my ($msg, $indent) = @_;
    $indent //= 0;

    warn $colours{'red'}->(format_line($indent, $msg)) . "\n";
}

# trace($msg, $indent) - Prints a grey, indented message to STDOUT, but only
# when verbose logging is enabled via set_verbose(1). A no-op otherwise.
# Params:
#   $msg    - Log message
#   $indent - Number of spaces to prepend (defaults to 0).
sub trace {
    return unless $verbose;

    my ($msg, $indent) = @_;
    $indent //= 0;

    print $colours{'grey'}->(format_line($indent, $msg)) . "\n";
}

1;