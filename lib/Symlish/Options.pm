package Symlish::Options;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(parse_command parse_directory parse_options);

use Getopt::Long qw(GetOptionsFromArray :config pass_through);

# Versioning
my $VERSION_MAJOR = 1;
my $VERSION_MINOR = 0;
my $VERSION_PATCH = 1;

# Usage string
my $USAGE = <<'USAGE';
Usage: symlish <command> <directory> [options]

Commands:
    link      Create symlinks from dotfiles to system locations
    unlink    Remove symlinks and restore backups
    status    Show current symlink status
    help      Display this help message
    version   Show version number

Options:
    --dry-run           Simulate without making changes
    --ignore  x,y,z     Comma-separated list of targets to skip
    --only    x,y,z     Process only these targets (mutually exclusive with --ignore)

Examples:
    symlish status ~/dotfiles
    symlish link ~/dotfiles --dry-run
    symlish unlink ~/dotfiles --only git,bash
USAGE

# parse_command($command, @supported) - Validates the command argument.
# Params:
#   $command   - The command string from CLI (e.g., 'link', 'unlink')
#   @supported - List of valid command names
# Returns: The validated command string
# Dies: If command is invalid, or help or version is requested (exits 0 for help and version)
sub parse_command {
    my ($command, @supported) = @_;

    # Handle help
    if (!$command || $command eq 'help' || $command eq '--help' || $command eq '-h') {
        print $USAGE;
        exit 0;
    }

    # Handle version
    if($command eq 'version' || $command eq '--version' || $command eq '-v') {
        print "Symlish version $VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH\n";
        exit 0;
    }

    # Validate
    for my $c (@supported) {
        return $command if ($c eq $command);
    }

    die "ERROR: Unknown command '$command'\n";
}

# parse_directory($directory) - Validates the directory argument.
# Params:
#   $directory - Path to the dotfiles directory
# Returns: The validated directory path
# Dies: If directory is missing or doesn't exist
sub parse_directory {
    my ($directory) = @_;

    die "ERROR: Missing <directory> argument\n"
        unless $directory;

    die "ERROR: '$directory' is not a valid directory\n" 
        unless -d $directory;

    return $directory;
}

# parse_options($argv_ref) - Parses command-line options.
# Params:
#   $argv_ref - Reference to @ARGV array
# Returns: Hash of parsed options (dry-run, ignore, only)
# Dies: If --ignore and --only are used together
sub parse_options {
    my ($argv_ref) = @_;

    my %options = ('dry-run' => 0);

    GetOptionsFromArray(
        $argv_ref,
        'dry-run'   => \$options{'dry-run'},
        'ignore=s'  => \$options{ignore},
        'only=s'    => \$options{only},
    ) or die $USAGE;

    # Validate mutually-exclusive options
    die "ERROR: --ignore and --only cannot be used together\n"
        if $options{ignore} && $options{only};

    # Convert comma-separated strings to arrays
    for my $key (qw(ignore only)) {
        if (defined $options{$key}) {
            $options{$key} = [ split /\s*,\s*/, $options{$key} ];
        }
    }

    return %options;
}

1;
