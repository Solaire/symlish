package Symlish::Config;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(load_config);

use Cwd qw(abs_path);
use File::Spec;
use YAML::PP qw(LoadFile);

# load_config($directory) - Loads and validates symlish.conf.yaml.
# Params:
#   $directory - Path to directory containing symlish.conf.yaml
# Returns: Hash ref with keys: config_path, config_dir, link
# Dies: If config file missing, invalid YAML, or validation fails
sub load_config {
    my ($directory) = @_;

    my $config_file = File::Spec->catfile($directory, 'symlish.conf.yaml');
    my $abs_config = abs_path($config_file);
    
    die "ERROR: '$config_file' not found\n"
        unless -e $abs_config;

    my $raw_data = eval { LoadFile($abs_config) };
    die "ERROR: Yaml syntax; '$@'\n" 
        if $@;

    die "ERROR: Invalid config; 'link' block is missing\n"
        unless ref($raw_data) eq 'HASH' && exists $raw_data->{link};

    die "ERROR: Invalid config; 'link' must be a hash\n"
        unless ref($raw_data->{link}) eq 'HASH';

    # Validate each entry
    while (my ($name, $entry_ref) = each %{ $raw_data->{link} }) {
        _validate_entry($name, $entry_ref);
    }

    return {
        config_path => $abs_config,
        config_dir  => abs_path($directory),
        link        => $raw_data->{link},
    };
}

# _validate_entry($name, $entry_ref) - Validates a single config entry.
# Params:
#   $name      - Name of the config entry (e.g., 'vscode', 'bash')
#   $entry_ref - Hash ref containing entry configuration
# Returns: 1 on success
# Dies: If entry is malformed or has invalid values
sub _validate_entry {
    my ($name, $entry_ref) = @_;

    die "ERROR: Invalid config entry '$name'; must be a hash\n"
        unless ref($entry_ref) eq 'HASH';

    die "ERROR: Invalid config entry '$name'; missing 'paths'\n"
        unless exists $entry_ref->{paths};

    die "ERROR: Invalid config entry '$name'; 'paths' must be an array\n"
        unless ref($entry_ref->{paths}) eq 'ARRAY';

    die "ERROR: Invalid config entry '$name'; missing 'target'\n"
        unless exists $entry_ref->{target};

    if (exists $entry_ref->{conflict}) {
        die "ERROR: Invalid 'conflict' value in '$name'; must be 'skip' or 'overwrite'\n"
            unless $entry_ref->{conflict} =~ /^(?:skip|overwrite)$/;
    }

    # Ensure boolean fields are actually boolean.
    for my $bool_key (qw(ignore ignore-empty)) {
        if (exists $entry_ref->{$bool_key}) {
            my $val = $entry_ref->{$bool_key};

            die "ERROR: Invalid '$bool_key' value in '$name'; must be boolean\n"
                unless !defined $val
                    || $val eq ''
                    || $val =~ /^[01]$/
                    || $val =~ /^(?:true|false)$/i;
        }
    }

    return 1;
}

1;