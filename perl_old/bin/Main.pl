#!/usr/bin/env perl
#
# symlish - Symbolic link manager for dotfiles
#
# Usage: symlish <command> <directory> [options]
#
# This script manages symlinks for your dotfiles using a YAML configuration.
# Run 'symlish help' for more information.
#

use strict;
use warnings;
use v5.16;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Getopt::Long qw(GetOptionsFromArray :config pass_through);
use Cwd qw(abs_path);

use Symlish::Config qw(load_config);
use Symlish::LinkTarget;
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
    symlish link ~/dotfiles --dry-run
    symlish status ~/dotfiles
    symlish unlink ~/dotfiles --only git,bash
USAGE

# Parse command and directory first
my $command   = shift @ARGV;
my $directory = shift @ARGV;

# Handle help or missing args
if (!$command || $command eq 'help' || $command eq '--help' || $command eq '-h') {
    print $USAGE;
    return 0;
}

unless ($directory) {
    die "Error: Missing <directory> argument\n\n$USAGE";
}

unless (-d $directory) {
    die "Error: '$directory' is not a valid directory\n";
}

unless ($command =~ /^(?:link|unlink|status)$/) {
    die "Error: Unknown command '$command'\n\n$USAGE";
}

# Parse options
my %options = ('dry-run' => 0);
GetOptionsFromArray(
    \@ARGV,
    'dry-run'  => \$options{'dry-run'},
    'ignore=s' => \$options{ignore},
    'only=s'   => \$options{only},
) or die $USAGE;

# Validate mutually exclusive options
if ($options{ignore} && $options{only}) {
    die "Error: --ignore and --only are mutually exclusive\n";
}

# Convert comma-separated strings to arrays
for my $key (qw(ignore only)) {
    if (defined $options{$key}) {
        $options{$key} = [ split /\s*,\s*/, $options{$key} ];
    }
}

# Load configuration
my $config = load_config($directory);

# Build targets from config
my @targets = _build_targets($config);

# Filter targets based on options
@targets = _filter_targets(\@targets, \%options);

# Process each target
for my $target (@targets) {
    print "💎 Processing: ${\$target->key}\n";

    unless ($target->is_valid) {
        print "   ⚠️  Skipping: no valid destination path found\n";
        next;
    }

    if ($target->ignore) {
        print "   ⚠️  Skipping: ignore flag is set\n";
        next;
    }

    # Dispatch to appropriate command handler
    if    ($command eq 'link')   { do_link($target, \%options) }
    elsif ($command eq 'unlink') { do_unlink($target, \%options) }
    elsif ($command eq 'status') { do_status($target) }
}

print "🏁 Done.\n";
return 0;

sub _build_targets {
    my ($config) = @_;

    my @targets;
    while (my ($key, $entry) = each %{ $config->{link} }) {
        push @targets, Symlish::LinkTarget->new(
            key        => $key,
            entry      => $entry,
            config_dir => $config->{config_dir},
        );
    }

    return @targets;
}

sub _filter_targets {
    my ($targets, $options) = @_;

    if ($options->{only}) {
        my %only = map { $_ => 1 } @{ $options->{only} };
        return grep { $only{ $_->key } } @$targets;
    }

    if ($options->{ignore}) {
        my %ignore = map { $_ => 1 } @{ $options->{ignore} };
        return grep { !$ignore{ $_->key } } @$targets;
    }

    return @$targets;
}

__END__

=head1 NAME

symlish - Symbolic link manager for dotfiles

=head1 SYNOPSIS

    symlish <command> <directory> [options]

    # Preview what would be linked
    symlish link ~/dotfiles --dry-run

    # Create symlinks
    symlish link ~/dotfiles

    # Remove symlinks and restore backups
    symlish unlink ~/dotfiles

    # Check current status
    symlish status ~/dotfiles

=head1 DESCRIPTION

Symlish helps you manage symbolic links for your dotfiles. It reads a
C<symlish.conf.yaml> file from your dotfiles directory and creates symlinks
in the appropriate system locations.

=head1 COMMANDS

=over 4

=item B<link>

Create symlinks for configured targets. Existing files are backed up
with a C<.bak> suffix.

=item B<unlink>

Remove symlinks created by symlish and restore any backups.

=item B<status>

Display the current state of all configured symlinks.

=item B<help>

Show usage information.

=back

=head1 OPTIONS

=over 4

=item B<--dry-run>

Simulate the operation without making changes.

=item B<--ignore> x,y,z

Skip the specified targets (comma-separated).

=item B<--only> x,y,z

Process only the specified targets (comma-separated).
Mutually exclusive with C<--ignore>.

=back

=head1 CONFIGURATION

Create a C<symlish.conf.yaml> in your dotfiles directory:

    link:
      bash:
        target: bash/**
        paths:
          - ~/
      vscode:
        target: vscode/*
        paths:
          - $APPDATA/Code/
          - ~/.config/Code/
      git:
        target: git/**
        ignore-empty: true
        paths:
          - ~/

=head1 AUTHOR

Your Name

=head1 LICENSE

Same terms as Perl itself.

=cut
