package Symlish::Targets;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(pick_profile build_targets filter_targets);

use Symlish::LinkTarget;
use Symlish::Logger qw(trace);

# pick_profile($config_ref, $requested) - Decide which top-level profile to use.
# Rules:
#   - If the config has exactly one profile, use it ($requested is ignored)
#   - Otherwise $requested must be defined and must name a real profile.
# Params:
#   $config_ref - Hash ref returned by load_config()
#   $requested  - Profile name from --profile, or undef if the flag was not given
# Returns: The chosen profile name (always a defined string)
# Dies: On missing or unknown profile when more than one is available in config
sub pick_profile {
    my ($config_ref, $requested) = @_;

    my $profiles = $config_ref->{profiles};
    if (scalar keys %$profiles == 1) {
        my ($only) = keys %$profiles;
        trace ("Auto-selecting the only profile: $only");
        return $only;
    }

    die "ERROR: missing profile\n"
        unless defined $requested;

    die "ERROR: unknown profile '$requested'\n"
        unless exists $profiles->{$requested};

    return $requested;
}

# build_targets($config_ref, $profile) - Builds LinkTarget objects for every
# entry under the chosen top-level profile
# Params:
#   $config_ref - Hash ref returned by load_config()
#   $profile    - Name of the top-level profile to materialise (e.g. 'default'
#                 for legacy configs, or 'personal' / 'work' for multi-configs)
# Returns: List of Symlish::LinkTarget objects (one per entry in the profile)
sub build_targets {
    my ($config_ref, $profile) = @_;

    my @targets;
    while (my ($name, $entry_ref) = each %{ $config_ref->{profiles}{$profile} }) {
        push @targets, Symlish::LinkTarget->new(
            key         => $name,
            entry       => $entry_ref,
            config_dir  => $config_ref->{dir},
        );
    }

    return @targets;
}

# filter_targets($targets_ref, $options_ref) - Filters targets by --only or --ignore.
# Params:
#   $targets_ref - Array ref of LinkTarget objects
#   $options_ref - Hash ref of parsed CLI options
# Returns: Filtered list of LinkTarget objects
sub filter_targets {
    my ($targets_ref, $options_ref) = @_; 

    if ($options_ref->{only}) {
        my %only = map { $_ => 1 } @{ $options_ref->{only} };
        return grep { $only{ $_->key } } @$targets_ref;
    }

    if ($options_ref->{ignore}) {
        my %ignore = map { $_ => 1 } @{ $options_ref->{ignore} };
        return grep { !$ignore{ $_->key } } @$targets_ref;
    }

    return @$targets_ref;
}

1;