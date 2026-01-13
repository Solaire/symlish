package Symlish::Commands;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(do_link do_unlink do_status);

use Symlish::Colour qw(red green yellow blue gray cyan);

sub do_link {

}

sub do_unlink {

}

sub do_status {
    my ($target) = @_;

    my (@green, @yellow, @gray, @cyan);

    for my $item ($target->items) {

        # Is empty?
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