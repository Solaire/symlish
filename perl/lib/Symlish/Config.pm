package Symlish::Config;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(load_config);

use Cwd qw(abs_path);
use File::Spec;
use YAML::PP qw(LoadFile);

sub load_config {
    my ($directory) = @_;

    my $config_file = File::Spec->catfile($directory, 'symlish.conf.yaml');
    my $abs_config = abs_path($config_file)
        or die "ERROR: 'symlish.conf.yaml' not found in '$directory'";

    my $raw_data = eval { LoadFile($abs_config) };
    die "ERROR: Yaml syntax; '$@'" if $@;

    die "ERROR: Invalid config; 'link' block is missing"
        unless ref($raw_data) eq 'HASH' && exists $raw_data->{link};

    die "ERROR: Invalid config; 'link' must be a hash"
        unless ref($raw_data->{link}) eq 'HASH';

    # Validate each entry
    while (my ($name, $entry) = each %{ $raw_data->{link} }) {
        _validate_entry($name, $entry);
    }

    return {
        config_path => $abs_config,
        config_dir  => abs_path($directory),
        link        => $raw_data->{link},
    };
}

sub _validate_entry {
    my ($name, $entry) = @_;

    die "ERROR: Invalid config entry '$name'; must be a hash"
        unless ref($entry) eq 'HASH';

    die "ERROR: Invalid config entry '$name'; missing 'paths'"
        unless exists $entry->{paths};

    die "ERROR: Invalid config entry '$name'; 'paths' must be an array"
        unless ref($entry->{paths}) eq 'ARRAY';

    die "ERROR: Invalid config entry '$name'; missing 'target'"
        unless exists $entry->{target};

    if (exists $entry->{conflict}) {
        die "ERROR: Invalid 'conflict' value in '$name'; must be 'skip' or 'overwrite'"
            unless $entry->{conflict} =~ /^(?:skip|overwrite)$/;
    }

    for my $bool_key (qw(ignore ignore-empty)) {
        if (exists $entry->{$bool_key}) {
            my $val = $entry->{$bool_key};

            die "ERROR: Invalid '$bool_key' value in '$name'; must be boolean"
                unless !defined $val
                    || $val eq ''
                    || $val =~ /^[01]$/
                    || $val =~ /^(?:true|false)$/i;
        }
    }

    return 1;
}

1;