package Symlish::Options;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(parse_command parse_directory parse_options);

use Getopt::Long qw(GetOptionsFromArray :config pass_through);

my $USAGE = <<'USAGE';
Usage: symlish <command> <directory> [options]

Commands:
    link      Create symlinks from dotfiles to system locations
    unlink    Remove symlinks and restore backups
    status    Show current symlink status
    help      Display this help message

Options:
    --dry-run           Simulate without making changes
    --ignore  x,y,z     Comma-separated list of targets to skip
    --only    x,y,z     Process only these targets (mutually exclusive with --ignore)

Examples:
    symlish status ~/dotfiles
    symlish link ~/dotfiles --dry-run
    symlish unlink ~/dotfiles --only git,bash
USAGE


sub parse_command {
    my ($command, @supported) = @_;

    # Handle help
    if (!$command || $command eq 'help' || $command eq '--help' || $command eq '-h') {
        print $USAGE;
        exit 0;
    }

    # Validate
    for my $c (@supported) {
        return $command if ($c eq $command);
    }

    die "ERROR: Unknown command '$command'\n";
}

sub parse_directory {
    my ($directory) = @_;

    die "ERROR: Missing <directory> argument"
        unless $directory;

    die "ERROR: '$directory' is not a valid directory" 
        unless -d $directory;

    return $directory;
}

sub parse_options {
    my ($args_ref) = @_;

    my %options = ('dry-run' => 0);

    GetOptionsFromArray(
        $args_ref,
        'dry-run'   => \$options{'dry-run'},
        'ignore=s'  => \$options{ignore},
        'only=s'    => \$options{only},
    ) or die $USAGE;

    # Validate mutually-exclusive options
    die "ERROR: --ignore and --only cannot be used together"
        if $options{ignore} && $options{only};

    # Convert comma-separated strings to arrays
    for my $key (qw(ignore only)) {
        if (defined $options{$key}) {
            $options{$key} = [ split /\s*,\s*/, $options{$key} ];
        }
    }

    return %options;
}

