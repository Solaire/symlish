package Symlish::Commands;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(do_link do_unlink do_status);

use Symlish::Colour qw(red green yellow blue gray cyan);

sub do_link {
    my ($target, $options) = @_;

    my $dry_run = $options->{'dry-run'};
    my (@green, @yellow, @gray, @cyan);

    for my $item ($target->items) {

        # Skip empty ?
        if ($target->ignore_empty && $item->is_source_empty) {
            push @yellow, "  Skipping empty: ${ \$item->source }\n";
            next
        }

        # If already linked, skip
        next if $item->is_here

        # Conflict: symlink exists but points elsewhere
        if ($item->is_symlink) {
            push @yellow,  "  Conflict: ${ \$item->target } (symlink exists)\n";
        }

        # Create backup if needed
        if ($item->can_backup and !$item->has_backup) {
            if ($dry_run) {
                push @gray, "  Would backup: ${ \$item->target }\n"
            } 
            else {
                $item->create_backup;
                push @cyan, "  Backed up: ${ \$item->target }\n"
            }
        }

        # Create the symlink
        if ($dry_run) {
            push @gray, "  Would link: ${ \$item->source } -> ${ \$item->target }\n"
        } 
        else {
            $item->create_symlink;
            push @cyan, "  Linked: ${ \$item->source } -> ${ \$item->target }\n"
        }
    }

    # Print all statuses
    print green($_)  for @green;
    print yellow($_) for @yellow;
    print gray($_)   for @gray;
    print cyan($_)   for @cyan;
}

sub do_unlink {
    my ($target, $options) = @_;

    my $dry_run = $options->{'dry-run'};
    my (@green, @yellow, @gray, @cyan);

    for my $item ($target->items) {
        
        # Only unlink if it points to our source
        next unless $item->is_here

        # Remove the symlink
        if ($dry_run) {
            push @gray, "  Would unlink: ${ \$item->target }\n"
        }
        else {
            $item->remove_symlink;
            push @cyan, "  Unlinked: ${ \$item->target }\n"
        }

        # Restore the backup if exists
        if ($item->has_backup) {
            if ($dry_run) {
                push @gray, "  Would restore: ${ \$item->backup }\n"
            }
            else {
                $item->restore_backup;
                push @cyan, "  Restored: ${ \$item->backup }\n"
            }
        }
        
    }

    # Print all statuses
    print green($_)  for @green;
    print yellow($_) for @yellow;
    print gray($_)   for @gray;
    print cyan($_)   for @cyan;
}

sub do_status {
    my ($target) = @_;

    my (@green, @yellow, @gray, @cyan);

    for my $item ($target->items) {

        # Skip empty ?
        if ($target->ignore_empty && $item->is_source_empty) {
            push @yellow, "  Skipping empty: ${\$item->source}\n";
            next;
        }

        # Show backup status
        if ($item->has_backup) {
            push @green, "  Backup exists: ${ \$item->backup }\n"
        }
            

        # Show link status
        if (!-l $item->target) {
            push @gray, "  ${ \$item->source } (not linked)\n";
        }
        elsif ($item->is_here) {
            push @cyan, "  ${ \$item->target } -> ${ \$item->source }\n";
        }
        else {
            my $actual = readlink($item->target) // '(unknown)';
            push @yellow, "  ${ \$item->target } -> $actual\n";
        }
    }

    # Print all statuses
    print green($_)  for @green;
    print yellow($_) for @yellow;
    print gray($_)   for @gray;
    print cyan($_)   for @cyan;
}

1;