package Symlish::Commands;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(do_link do_unlink do_status);

use Symlish::Logger qw(format_line green yellow gray cyan);

sub do_link {
    my ($target, $options) = @_;

    my $dry_run = $options->{'dry-run'};
    my (@green, @yellow, @gray, @cyan);

    for my $item ($target->items) {

        # Skip empty?
        if ($target->ignore_empty && $item->is_source_empty) {
            push @yellow, format_line(2, "Skipping empty: ${ \$item->source }");
            next
        }

        # If already linked, skip
        next if $item->is_here;

        # Conflict: symlink exists but points elsewhere
        if ($item->is_symlink) {
            push @yellow, format_line(2, "Conflict: ${ \$item->target } (symlink exists)");
        }

        # Create backup if needed
        if ($item->can_backup and !$item->has_backup) {
            if ($dry_run) {
                push @gray, format_line(2, "Would backup: ${ \$item->target }");
            } 
            else {
                $item->create_backup;
                push @cyan, format_line(2, "Backed up: ${ \$item->target }");
            }
        }

        # Create the symlink
        if ($dry_run) {
            push @gray, format_line(2, "Would link: ${ \$item->source } -> ${ \$item->target }");
        } 
        else {
            $item->create_symlink;
            push @cyan, format_line(2, "Linked: ${ \$item->source } -> ${ \$item->target }");
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
        next unless $item->is_here;

        # Remove the symlink
        if ($dry_run) {
            push @gray, format_line(2, "Would unlink: ${ \$item->target }");
        }
        else {
            $item->remove_symlink;
            push @cyan, format_line(2, "Unlinked: ${ \$item->target }");
        }

        # Restore the backup if exists
        if ($item->has_backup) {
            if ($dry_run) {
                push @gray, format_line(2, "Would restore: ${ \$item->backup }");
            }
            else {
                $item->restore_backup;
                push @cyan, format_line(2, "Restored: ${ \$item->backup }");
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

        # Skip empty?
        if ($target->ignore_empty && $item->is_source_empty) {
            push @yellow, format_line(2, "Skipping empty: ${\$item->source}");
            next;
        }

        # Show backup status
        if ($item->has_backup) {
            push @green, format_line(2, "Backup exists: ${ \$item->backup }");
        }
            

        # Show link status
        if (!-l $item->target) {
            push @gray, format_line(2, "${ \$item->source } (not linked)");
        }
        elsif ($item->is_here) {
            push @cyan, format_line(2, "${ \$item->target } -> ${ \$item->source }");
        }
        else {
            my $actual = readlink($item->target) // '(unknown)';
            push @yellow, format_line(2, "${ \$item->target } -> $actual");
        }
    }

    # Print all statuses
    print green($_)  for @green;
    print yellow($_) for @yellow;
    print gray($_)   for @gray;
    print cyan($_)   for @cyan;
}

1;