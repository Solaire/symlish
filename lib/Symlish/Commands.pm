package Symlish::Commands;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(do_link do_unlink do_status);

use Symlish::Logger qw(info trace);

# do_link($target, $options_ref) - Creates symlinks for a target.
# Handles: skipping empty sources, conflict detection, backup creation.
# In dry-run mode, only prints what would be done.
# Params:
#   $target      - LinkTarget object
#   $options_ref - Hash ref with 'dry-run' flag
sub do_link {
    my ($target, $options_ref) = @_;

    my $dry_run = $options_ref->{'dry-run'};
    my (@yellow, @grey, @cyan);

    for my $item ($target->items) {

        # Skip empty?
        if ($target->ignore_empty && $item->is_source_empty) {
            push @yellow, "Skipping empty: ${ \$item->source }";
            next
        }

        # If already linked, skip
        next if $item->is_here;

        # Conflict: a symlink exists but points elsewhere
        if ($item->is_symlink) {
            if ($target->conflict eq 'overwrite') {
                unless ($dry_run) {
                    $item->remove_symlink;
                }
                push @yellow, "Overwriting conflict: ${ \$item->target }";
            }
            else {
                push @yellow, "Conflict: ${ \$item->target } (symlink exists, skipping)";
                next;
            }
        }

        # Create backup if needed
        if ($item->can_backup and !$item->has_backup) {
            if ($dry_run) {
                push @grey, "Would backup: ${ \$item->target }";
            } 
            else {
                $item->create_backup;
                push @cyan, "Backed up: ${ \$item->target }";
            }
        }

        # Create the symlink
        if ($dry_run) {
            push @grey, "Would link: ${ \$item->source } -> ${ \$item->target }";
        } 
        else {
            $item->create_symlink;
            push @cyan, "Linked: ${ \$item->source } -> ${ \$item->target }";
        }
    }

    # Print all statuses
    info ($_, 'yellow', 2)  for @yellow;
    info ($_, 'grey', 2)    for @grey;
    info ($_, 'cyan', 2)    for @cyan;
}

# do_unlink($target, $options_ref) - Removes symlinks and restores backups.
# Only removes symlinks that point to our source files.
# In dry-run mode, only prints what would be done.
# Params:
#   $target      - LinkTarget object
#   $options_ref - Hash ref with 'dry-run' flag
sub do_unlink {
    my ($target, $options_ref) = @_;

    my $dry_run = $options_ref->{'dry-run'};
    my (@yellow, @grey, @cyan);

    for my $item ($target->items) {
        
        # Only unlink if it points to our source
        next unless $item->is_here;

        # Remove the symlink
        if ($dry_run) {
            push @grey, "Would unlink: ${ \$item->target }";
        }
        else {
            $item->remove_symlink;
            push @cyan, "Unlinked: ${ \$item->target }";
        }

        # Restore the backup if exists
        if ($item->has_backup) {
            if ($dry_run) {
                push @grey, "Would restore: ${ \$item->backup }";
            }
            else {
                $item->restore_backup;
                push @cyan, "Restored: ${ \$item->backup }";
            }
        }
        
    }

    # Print all statuses
    info ($_, 'yellow', 2)  for @yellow;
    info ($_, 'grey', 2)    for @grey;
    info ($_, 'cyan', 2)    for @cyan;
}

# do_status($target) - Displays current symlink status for a target.
# Shows: backup existence, link status (linked/not linked/wrong target).
# Params:
#   $target - LinkTarget object
sub do_status {
    my ($target) = @_;

    my (@yellow, @grey, @cyan);

    for my $item ($target->items) {

        # Skip empty?
        if ($target->ignore_empty && $item->is_source_empty) {
            push @yellow, "Skipping empty: ${\$item->source}";
            next;
        }

        # Show backup status
        if ($item->has_backup) {
            push @cyan, "Backup exists: ${ \$item->backup }";
        }
            

        # Show link status
        if (!-l $item->target) {
            push @grey, "${ \$item->source } (not linked)";
        }
        elsif ($item->is_here) {
            push @cyan, "${ \$item->target } -> ${ \$item->source }";
        }
        else {
            my $actual = readlink($item->target) // '(unknown)';
            push @yellow, "${ \$item->target } -> $actual";
        }
    }

    # Print all statuses
    info ($_, 'yellow', 2)  for @yellow;
    info ($_, 'grey', 2)    for @grey;
    info ($_, 'cyan', 2)    for @cyan;
}

1;