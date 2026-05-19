package Symlish::Config;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(load_config);

use Cwd qw(abs_path);
use File::Spec;

use Symlish::Logger qw(info trace warning);

# load_config($directory) - Loads and validates symlish.conf.ini.
# Params:
#   $directory - Path to directory containing symlish.conf.ini
# Returns: Hash ref with keys: path, dir, profiles
# Dies: If config file missing, invalid syntax, or validation fails
sub load_config {
    my ($directory) = @_;

    my $config_file = File::Spec->catfile($directory, 'symlish.conf.ini');
    my $abs_config = abs_path($config_file);

    die "ERROR: '$config_file' not found\n"
        unless -e $abs_config;

    my $config_ref = _parse_ini($abs_config);

    # Validate each entry
    while (my ($profile_name, $profile_ref) = each %$config_ref) {
        warning ("'$profile_name' has no elements.")
            if scalar keys %$profile_ref == 0;

        while (my ($entry_name, $entry_ref) = each %$profile_ref) {
            _validate_entry($entry_name, $entry_ref);
        }
    }

    return {
        path     => $abs_config,
        dir      => abs_path($directory),
        profiles => $config_ref,
    };
}

# _parse_ini($file) - Parses an INI config file into a hash.
# Recognised syntax:
#   - '[[name]]'    Top-level profile header
#   - '[name]'      Config entry header; must follow a [[profile]] or trigger
#                   implicit 'default' profile, but never both (see _validate_config)
#   - 'key = value' Assignment (legal only inside a [name] entry)
#   - ';' or '#'    Line comments and blank lines
# Params:
#   $file - Absolute path to the INI file
# Returns: Hash ref shaped as:
#          { <profile> => { <entry> => { <key> = <value>, ... }, ... }, ... }
# Dies: On unrecognised syntax, orphaned keys, or mixed implicit/explicit
#       profile layout
sub _parse_ini {
    my ($file) = @_;

    open my $fh, '<', $file or die "ERROR: Cannot open '$file': $!\n";

    my $implicit_default = 0;
    my $explicit_profile = 0;

    my %data;    # Complete config data
    my $profile; # Top-level profile, marked by '[[name]]'
    my $entry;   # Config entry (bash, git, emacs, etc.) marked by '[name]'

    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;  # trim

        next if $line eq '';       # blank line
        next if $line =~ /^[;#]/;  # comment

        # Profile header: [[name]]
        if ($line =~ /^\[\[([^\]]+)\]\]$/) {
            $explicit_profile = 1;
            $profile = $1;
            $entry = undef;
            $data{$profile} //= {};
            trace($profile);
            next;
        }

        # Entry header: [name]
        if ($line =~ /^\[([^\]]+)\]$/) {
            unless (defined $profile) {
                $implicit_default = 1;
                $profile = 'default';
                $data{$profile} //= {};
            }

            $entry = $1;
            $data{$profile}{$entry} //= {};
            trace ("$profile: $entry", 2);
            next;
        }

        # Key = value
        if ($line =~ /^([\w-]+)\s*=\s*(.*)$/) {
            my ($key, $val) = ($1, $2);
            $val =~ s/\s+$//;  # rtrim value

            die "ERROR: orphaned key '$key'\n"
                unless defined $entry;

            if ($key eq 'paths') {
                # Split comma-separated list and trim each entry
                my @paths = map { s/^\s+|\s+$//gr } split /,/, $val;
                $data{$profile}{$entry}{$key} = \@paths;
            }
            else {
                $data{$profile}{$entry}{$key} = $val;
            }
            next;
        }

        die "ERROR: Unrecognised line in config: '$line'\n";
    }

    close $fh;
    _validate_config($implicit_default, $explicit_profile);

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
    
    die "ERROR: Invalid config entry '$name'; 'paths' must contain at least one value\n"
        unless @{ $entry_ref->{paths} };

    for my $p (@{ $entry_ref->{paths} }) {
        die "ERROR: Invalid config entry '$name'; 'paths' contains an empty value\n"
            if $p eq '';
    }

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

# _validate_config($implicit_default, $explicit_profile) - Enforces the 
# two valid config layouts:
#   - LEGACY: only bare [entry] headers (implicit_default=1, explicit_profile=0)
#   - MULTI:  only [[profile]] headers wrapping [entry] headers
#             (implicit_default=0, explicit_profile=1)
# Rejects two invalid cases:
#   - empty config (both flags false)
#   - mixed layout where [entry] appears before any [[profile]] and 
#     [[profile]] also appears (both flags true)
# Params:
#   $implicit_default - True if an implicit 'default' profile was created
#                       because a bare [entry] preceded any [[profile]]
#   $explicit_profile - True if at least one [[profile]] header was parsed
# Returns: 1 on success
# Dies: On empty or mixed layouts
sub _validate_config {
    my ($implicit_default, $explicit_profile) = @_;

    die "ERROR: Invalid config; most likely empty\n"
        unless $implicit_default || $explicit_profile;

    die "ERROR: Invalid config; implicit and explicit profiles cannot be used together\n"
        if $implicit_default && $explicit_profile;

    trace ("Config type: legacy")
        if $implicit_default && !$explicit_profile;

    trace ("Config type: multi")
        if !$implicit_default && $explicit_profile;
    
    return 1;
}

1;