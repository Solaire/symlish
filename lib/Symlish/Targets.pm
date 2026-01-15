package Symlish::Targets;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(build_targets filter_targets);

use Symlish::LinkTarget;

# build_targets($config_ref) - Creates LinkTarget objects from config.
# Params:
#   $config_ref - Hash ref returned by load_config()
# Returns: List of Symlish::LinkTarget objects
sub build_targets {
    my ($config_ref) = @_;

    my @targets;
    while (my ($name, $entry_ref) = each %{ $config_ref->{link} }) {
        push @targets, Symlish::LinkTarget->new(
            key         => $name,
            entry       => $entry_ref,
            config_dir  => $config_ref->{config_dir},
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