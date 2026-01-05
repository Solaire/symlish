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

use Symlish::App;

exit Symlish::App->run(@ARGV);

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
