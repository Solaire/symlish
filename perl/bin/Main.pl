#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

# use Data::Dumper qw(Dumper);

use Symlish::Config qw(load_config);
use Symlish::Targets qw(build_targets filter_targets);
use Symlish::Logger qw(format_line yellow blue);
use Symlish::Commands qw(do_link do_unlink do_status);
use Symlish::Options qw(parse_command parse_directory parse_options);


sub main {
    # Parse the command and directory
    my $command   = parse_command   (shift @ARGV, qw(link unlink status));
    my $directory = parse_directory (shift @ARGV);
    my %options   = parse_options   (     \@ARGV);

    # Load and validate config
    my $config = load_config($directory);

    # Build and filter the targets
    my @targets = build_targets($config);
    @targets = filter_targets(\@targets, \%options);

    # Process command
    for my $target (@targets) {
        print blue format_line(0, "Processing ${ \$target->key }");

        unless ($target->is_valid) {
            print yellow format_line(2, "Skipping: no valid destination path found");
            next;
        }

        if ($target->ignore) {
            print yellow format_line(2, "Skipping: ignore flag is set");
            next;
        }

        # Dispatch command
        if    ($command eq 'link')   { do_link  ($target, \%options) }
        elsif ($command eq 'unlink') { do_unlink($target, \%options) }
        elsif ($command eq 'status') { do_status($target)            }
    }
}

main;

exit 0;