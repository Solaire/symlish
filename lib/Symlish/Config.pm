package Symlish::Config;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(load_config);

use Cwd qw(abs_path);
use File::Spec;

# load_config($directory) - Loads and validates symlish.conf.ini.
# Params:
#   $directory - Path to directory containing symlish.conf.ini
# Returns: Hash ref with keys: config_path, config_dir, link
# Dies: If config file missing, invalid syntax, or validation fails
sub load_config {
    my ($directory) = @_;

    my $config_file = File::Spec->catfile($directory, 'symlish.conf.ini');
    my $abs_config = abs_path($config_file);

    die "ERROR: '$config_file' not found\n"
        unless -e $abs_config;

    my $link = _parse_ini($abs_config);

    die "ERROR: Invalid config; no target sections defined\n"
        unless %$link;

    # Validate each entry
    while (my ($name, $entry_ref) = each %$link) {
        _validate_entry($name, $entry_ref);
    }

    return {
        config_path => $abs_config,
        config_dir  => abs_path($directory),
        link        => $link,
    };
}

# _parse_ini($file) - Parses an INI config file into a hash of sections.
# Supports ; and # comments, [section] headers, and key = value pairs.
# The special key 'paths' is split on commas into an array ref.
# Params:
#   $file - Absolute path to the INI file
# Returns: Hash ref mapping section name -> hash ref of key/value pairs
# Dies: On unrecognized syntax or keys outside a section
sub _parse_ini {
    my ($file) = @_;

    open my $fh, '<', $file or die "ERROR: Cannot open '$file': $!\n";

    my %data;
    my $section;

    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;  # trim

        next if $line eq '';        # blank line
        next if $line =~ /^[;#]/;  # comment

        # Section header: [name]
        if ($line =~ /^\[([^\]]+)\]$/) {
            $section = $1;
            $data{$section} //= {};
            next;
        }

        # Key = value
        if ($line =~ /^([\w-]+)\s*=\s*(.*)$/) {
            my ($key, $val) = ($1, $2);
            $val =~ s/\s+$//;  # rtrim value

            die "ERROR: Key '$key' found outside of a section\n"
                unless defined $section;

            if ($key eq 'paths') {
                # Split comma-separated list and trim each entry
                my @paths = map { s/^\s+|\s+$//gr } split /,/, $val;
                $data{$section}{paths} = \@paths;
            }
            else {
                $data{$section}{$key} = $val;
            }
            next;
        }

        die "ERROR: Unrecognized line in config: '$line'\n";
    }

    close $fh;
    return \%data;
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