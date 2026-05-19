package SymlishTest;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(capture capture_warnings);

# SymlishTest - Test helpers shared across t/*.t files.
# Public API:
#   capture($coderef)          - Invokes coderef and captures STDOUT into a string buffer
#   capture_warnings($coderef) - Invokes coderef and captures `warn()` output into an array.

# capture($coderef) - Runs $code with STDOUT redirected into a string buffer.
# Restores STDOUT on success and rethrows any exception from $code (after
# restore) so the test framework still sees failures.
# Params: 
#   $code - Coderef to invoke
# Returns: Captured STDOUT contents as a string
sub capture {
    my ($coderef) = @_;

    my $output = '';
    open my $fh, '>', \$output or die "Cannot create capture handle: $!";
    my $old = select($fh);
    eval { $coderef->() };
    my $err = $@;
    select($old);
    die $err if $err;
    return $output;
}

# capture_warnings($coderef) - Runs $coderef with $SIG{__WARN__} installed so that
# every warn() call is appended to an internal list instead of hitting STDERR.
# Note: only intercepts Perl's warn() builtin. Code that writes directly to 
# STDERR (e.g. print STDERR ...) is NOT captured.
# Params:
#   $code - Coderef to invoke
# Returns: Array ref of warning messages in the order they were emitted
sub capture_warnings {
    my ($coderef) = @_;

    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    $coderef->();
    return \@warnings;
}

1;