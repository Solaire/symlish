package Symlish::Options;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(parse_command parse_directory parse_options);

use Getopt::Long qw(GetOptionsFromArray :config);
use Symlish::Logger qw(set_verbose info);

# Versioning
my $VERSION_MAJOR = 1;
my $VERSION_MINOR = 0;
my $VERSION_PATCH = 1;

# Usage string
my $USAGE = <<'USAGE';
Usage: symlish <command> <directory> [options]

Commands:
    apply     Create symlinks from dotfiles to system locations
    clean     Remove symlinks and restore backups
    status    Show current symlink status
    help      Display this help message
    version   Show version number

Options:
    --dry-run           Simulate without making changes
    --ignore  x,y,z     Comma-separated list of targets to skip (mutually exclusive with --only)
    --only    x,y,z     Process only these targets (mutually exclusive with --ignore)
    --verbose, -v       Enable verbose logging

Examples:
    symlish status ~/dotfiles
    symlish apply ~/dotfiles --dry-run
    symlish clean ~/dotfiles --only git,bash
USAGE

# parse_command($command, @supported) - Validates the command argument.
# Params:
#   $command   - The command string from CLI (e.g., 'apply', 'clean')
#   @supported - List of valid command names
# Returns: The validated command string
# Dies: If command is invalid, or help or version is requested (exits 0 for help and version)
sub parse_command {
    my ($command, @supported) = @_;

    # Handle help
    if (!$command || $command eq 'help' || $command eq '--help' || $command eq '-h') {
        info ($USAGE);
        exit 0;
    }

    # Handle version
    if($command eq 'version' || $command eq '--version' || $command eq '-v') {
        info ("Symlish version $VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH\n");
        exit 0;
    }

    # Validate
    for my $c (@supported) {
        return $command if ($c eq $command);
    }

    die "Unknown command '$command'\n";
}

# parse_directory($directory) - Validates the directory argument.
# Params:
#   $directory - Path to the dotfiles directory
# Returns: The validated directory path
# Dies: If directory is missing or doesn't exist
sub parse_directory {
    my ($directory) = @_;

    die "Missing <directory> argument\n"
        unless $directory;

    die "'$directory' is not a valid directory\n" 
        unless -d $directory;

    return $directory;
}

# parse_options($argv_ref) - Parses command-line options.
# Params:
#   $argv_ref - Reference to @ARGV array
# Returns: Hash of parsed options (dry-run, ignore, only, verbose)
# Dies: If --ignore and --only are used together
sub parse_options {
    my ($argv_ref) = @_;

    my %options = (
        'dry-run' => 0,
        'verbose' => 0,
    );

    GetOptionsFromArray(
        $argv_ref,
        'dry-run'   => \$options{'dry-run'},
        'ignore=s'  => \$options{ignore},
        'only=s'    => \$options{only},
        'verbose|v' => \$options{verbose},
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

    # Set verbose flag
    set_verbose($options{verbose});

    return %options;
}

1;
