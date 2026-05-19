package SymlishTest;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(capture capture_warnings write_file read_file write_ini);

# SymlishTest - Test helpers shared across t/*.t files.
# Public API:
#   capture($coderef)           - Invokes coderef and captures STDOUT into a string buffer
#   capture_warnings($coderef)  - Invokes coderef and captures `warn()` output into an array.
#   write_file($path, $content) - Writes $content to $path.
#   read_file($path)            - Read the entire contents of $path into a string.
#   write_ini($path, $content)  - Create mock ini configuration file.

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

# write_file($path, $content) - Writes $content to $path.
# Used to set up fixture files in temp directories.
# Params:
#   $path    - Absolute file path
#   $content - String to write
# Dies: on failure
sub write_file {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print $fh $content;
    close $fh;
}

# read_file($path) - Read the entire contents of $path into a string.
# Params:
#   $path - Absolute file path
# Returns: File contents as a single string
# Dies: on failure
sub read_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read $path: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

# write_ini($path, $content) - Create mock ini configuration file.
# Params:
#   $path    - Absolute file path
#   $content - mock config ini content
# Dies: on failure
sub write_ini {
    my ($path, $content) = @_;
    my $file = File::Spec->catfile($path, 'symlish.conf.ini');
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh $content;
    close $fh;
}

1;