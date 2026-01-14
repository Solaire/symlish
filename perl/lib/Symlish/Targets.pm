package Symlish::Targets;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(build_targets filter_targets);

use Symlish::LinkTarget;

sub build_targets {
    my ($config) = @_;

    my @targets;
    while (my ($name, $entry) = each %{ $config->{link} }) {
        push @targets, Symlish::LinkTarget->new(
            key         => $name,
            entry       => $entry,
            config_dir  => $config->{config_dir},
        );
    }

    return @targets;
}

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