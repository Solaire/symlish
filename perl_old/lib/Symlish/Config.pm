package Symlish::Config;

use strict;
use warnings;
use v5.16;

use Carp qw(croak);
use Cwd qw(abs_path);
use File::Spec;
use YAML::PP qw(LoadFile);

use Exporter 'import';
our @EXPORT_OK = qw(load_config);

=head1 NAME

Symlish::Config - Configuration loader for Symlish

=head1 SYNOPSIS

    use Symlish::Config qw(load_config);
    
    my $config = load_config('/path/to/dotfiles');

=head1 DESCRIPTION

Handles loading and validating the symlish.conf.yaml configuration file.

=cut

sub load_config {
    my ($config_dir) = @_;

    my $config_file = File::Spec->catfile($config_dir, 'symlish.conf.yaml');
    my $abs_config  = abs_path($config_file)
        or croak "Config file does not exist: $config_file";

    my $raw = eval { LoadFile($abs_config) };
    croak "YAML syntax error: $@" if $@;

    croak "Invalid config: 'link' block is missing"
        unless ref($raw) eq 'HASH' && exists $raw->{link};

    croak "Invalid config: 'link' must be a hash"
        unless ref($raw->{link}) eq 'HASH';

    # Validate each entry
    while (my ($name, $entry) = each %{ $raw->{link} }) {
        _validate_entry($name, $entry);
    }

    return {
        config_path => $abs_config,
        config_dir  => abs_path($config_dir),
        link        => $raw->{link},
    };
}

sub _validate_entry {
    my ($name, $entry) = @_;

    croak "Invalid config entry '$name': must be a hash"
        unless ref($entry) eq 'HASH';

    croak "Invalid config entry '$name': missing 'paths'"
        unless exists $entry->{paths};

    croak "Invalid config entry '$name': 'paths' must be an array"
        unless ref($entry->{paths}) eq 'ARRAY';

    croak "Invalid config entry '$name': missing 'target'"
        unless exists $entry->{target};

    if (exists $entry->{conflict}) {
        croak "Invalid 'conflict' value in '$name': must be 'skip' or 'force'"
            unless $entry->{conflict} =~ /^(?:skip|force)$/;
    }

    for my $bool_key (qw(ignore ignore-empty)) {
        if (exists $entry->{$bool_key}) {
            my $val = $entry->{$bool_key};
            # YAML::PP parses true/false as 1/0 or strings
            croak "Invalid '$bool_key' value in '$name': must be boolean"
                unless !defined $val 
                    || $val eq '' 
                    || $val =~ /^[01]$/ 
                    || $val =~ /^(?:true|false)$/i;
        }
    }

    return 1;
}

1;

__END__

=head1 FUNCTIONS

=head2 load_config($directory)

Loads the symlish.conf.yaml from the given directory. Returns a hashref with:

    {
        config_path => '/absolute/path/to/symlish.conf.yaml',
        config_dir  => '/absolute/path/to/dotfiles',
        link        => { ... },  # The link configuration hash
    }

Dies on error with a descriptive message.

=cut
