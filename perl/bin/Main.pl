#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Getopt::Long qw(GetOptionsFromArray :config pass_through);
use Data::Dumper qw(Dumper);

use Symlish::Config qw(load_config);
use Symlish::Targets qw(build_targets filter_targets);
use Symlish::Colour qw(red green yellow blue);
use Symlish::Commands qw(do_link do_unlink do_status);

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

# === COMMAND + DIRECTORY ===

# Parse the command and directory
my $command   = shift @ARGV;
my $directory = shift @ARGV;

# Handle help
if (!$command || $command eq 'help' || $command eq '--help' || $command eq '-h') {
    print $USAGE;
    exit 0;
}

# Validate <command>
die "ERROR: 'Unknown command '$command'\n"
    unless $command =~ /^(?:link|unlink|status)$/;

# Validate <directory>
die "ERROR: Missing <directory> argument\n"
    unless $directory;

die "ERROR: '$directory' is not a valid directory\n"
    unless -d $directory;


# === OPTIONS ===


# Parse the options
my %options = ('dry-run' => 0);
GetOptionsFromArray(
    \@ARGV,
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


# === LOAD + VALIDATE CONFIG ===


# Load and validate config
my $config = load_config($directory);

# Build and filter the targets
my @targets = build_targets($config);
@targets = filter_targets(\@targets, \%options);

# DEBUG: dump config data
# print '$config' . Dumper($config) . "\n\n";
# print '@targets' . Dumper(@targets) . "\n\n";


# === PROCESS COMMAND ===


for my $target (@targets) {
    print blue "Processing ${ \$target->key }\n";

    unless ($target->is_valid) {
        print yellow "  Skipping: no valid destination path found\n";
        next;
    }

    if ($target->ignore) {
        print yellow "  Skipping: ignore flag is set\n";
        next;
    }

    # Dispatch command
    if    ($command eq 'link')   {}#{ do_link($target, \%options) }
    elsif ($command eq 'unlink') {}#{ do_unlink($target, \%options) }
    elsif ($command eq 'status') { do_status($target) }
}


exit 0;