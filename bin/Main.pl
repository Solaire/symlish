#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Symlish::Options    qw(parse_command parse_directory parse_options);
use Symlish::Config     qw(load_config);
use Symlish::Targets    qw(build_targets filter_targets);
use Symlish::Logger     qw(info);
use Symlish::Commands   qw(do_link do_unlink do_status);


# main() - Entry point for the symlish CLI application.
# Parses command-line arguments, loads configuration, builds targets,
# and dispatches to the appropriate command handler (link/unlink/status).
sub main {
    # Parse the command and directory
    my $command     = parse_command   (shift @ARGV, qw(link unlink status));
    my $directory   = parse_directory (shift @ARGV);
    my %options     = parse_options   (\@ARGV);

    # Load and validate config
    my $config_ref = load_config($directory);

    # Build and filter the targets
    my @targets = build_targets($config_ref);
    @targets = filter_targets(\@targets, \%options);

    # Process command
    for my $target (@targets) {
        info ("Processing ${ \$target->key }", 'green');

        unless ($target->is_valid) {
            info ("Skipping: no valid destination path found", 'yellow', 2);
            next;
        }

        if ($target->ignore) {
            info ("Skipping: ignore flag is set", 'yellow', 2);
            next;
        }

        # Dispatch command
        if    ($command eq 'link')   { do_link  ($target, \%options) }
        elsif ($command eq 'unlink') { do_unlink($target, \%options) }
        elsif ($command eq 'status') { do_status($target)              }
    }

    info("Done", 'green');
}

main;

exit 0;