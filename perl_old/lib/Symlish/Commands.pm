package Symlish::Commands;

use strict;
use warnings;
use v5.16;

use Exporter 'import';
our @EXPORT_OK = qw(do_link do_unlink do_status);

=head1 NAME

Symlish::Commands - Command handlers for Symlish

=head1 SYNOPSIS

    use Symlish::Commands qw(do_link do_unlink do_status);
    
    do_link($target, $options);

=head1 DESCRIPTION

Implements the link, unlink, and status commands.

=cut

sub do_link {
    my ($target, $options) = @_;
    my $dry_run = $options->{'dry-run'};

    for my $item ($target->items) {
        # Skip empty sources if ignore_empty is set
        if ($target->ignore_empty && $item->is_source_empty) {
            print "⚠️  Skipping empty: ${\$item->source}\n";
            next;
        }

        # Already linked correctly - nothing to do
        next if $item->is_here;

        # Conflict: symlink exists but points elsewhere
        if ($item->is_symlink) {
            print "⚠️  Conflict: ${\$item->target} (symlink exists)\n";
            next;
        }

        # Create backup if needed
        if ($item->can_backup && !$item->has_backup) {
            if ($dry_run) {
                print "🔁 Would backup: ${\$item->target}\n";
            } else {
                $item->create_backup;
                print "🔁 Backed up: ${\$item->target}\n";
            }
        }

        # Create the symlink
        if ($dry_run) {
            print "📝 Would link: ${\$item->source} → ${\$item->target}\n";
        } else {
            $item->create_symlink;
            print "🔗 Linked: ${\$item->source} → ${\$item->target}\n";
        }
    }
}

sub do_unlink {
    my ($target, $options) = @_;
    my $dry_run = $options->{'dry-run'};

    for my $item ($target->items) {
        # Only unlink if it points to our source
        next unless $item->is_here;

        # Remove the symlink
        if ($dry_run) {
            print "🗑️  Would unlink: ${\$item->target}\n";
        } else {
            $item->remove_symlink;
            print "🗑️  Unlinked: ${\$item->target}\n";
        }

        # Restore backup if exists
        if ($item->has_backup) {
            if ($dry_run) {
                print "🔁 Would restore: ${\$item->backup}\n";
            } else {
                $item->restore_backup;
                print "🔁 Restored: ${\$item->backup}\n";
            }
        }
    }
}

sub do_status {
    my ($target) = @_;

    for my $item ($target->items) {
        # Show backup status
        if ($item->has_backup) {
            print "🔁 Backup exists: ${\$item->backup}\n";
        }

        # Show link status
        if (!-l $item->target) {
            print "⚪ ${\$item->source} (not linked)\n";
        } elsif ($item->is_here) {
            print "🔗 ${\$item->target} → ${\$item->source}\n";
        } else {
            my $actual = readlink($item->target) // '(unknown)';
            print "⚠️  ${\$item->target} → $actual (different source)\n";
        }
    }
}

1;

__END__

=head1 FUNCTIONS

=head2 do_link($target, $options)

Create symlinks for all items in the target. Respects ignore_empty setting
and creates backups of existing files.

=head2 do_unlink($target, $options)

Remove symlinks that point to our source files. Restores backups if they exist.

=head2 do_status($target)

Display the current status of all symlinks in the target.

=cut
