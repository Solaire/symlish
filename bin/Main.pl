#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Symlish::Options    qw(parse_command parse_directory parse_options);
use Symlish::Config     qw(load_config);
use Symlish::Targets    qw(pick_profile build_targets filter_targets);
use Symlish::Logger     qw(info);
use Symlish::Commands   qw(do_apply do_clean do_status);


# main() - Entry point for the symlish CLI application.
# Flow:
#   1. Parse the command, directory, and options from @ARGV.
#   2. Load and validate symlish.conf.ini.
#   3. Pick a top-level profile: auto-select when only one exists, otherwise
#      require --profile.
#   4. Build the per-entry LinkTarget list and apply --only / --ignore filters
#   5. Dispatch each target to the specified command executor, skipping targets
#      that have no valid destination or are flagged ignore=true.
sub main {
    # Parse the command and directory
    my $command     = parse_command   (shift @ARGV, qw(apply clean status));
    my $directory   = parse_directory (shift @ARGV);
    my %options     = parse_options   (\@ARGV);

    # Load config and pick the profile to operate on
    my $config_ref = load_config($directory);
    my $profile    = pick_profile($config_ref, $options{profile});

    # Build and filter the targets
    my @targets = build_targets($config_ref, $profile);
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
        if    ($command eq 'apply')  { do_apply ($target, \%options) }
        elsif ($command eq 'clean')  { do_clean ($target, \%options) }
        elsif ($command eq 'status') { do_status($target)              }
    }

    info("Done", 'green');
}

main;

exit 0;