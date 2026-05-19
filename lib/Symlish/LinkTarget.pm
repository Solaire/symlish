package Symlish::LinkTarget;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use File::Basename qw(basename);
use File::Glob qw(bsd_glob);

use Symlish::LinkItem;

# new(%args) - Constructor for LinkTarget.
# Params (via %args):
#   key        - Unique identifier for this target (e.g., 'vscode')
#   entry      - Hash ref of config entry (target, paths, ignore, etc.)
#   config_dir - Absolute path to the dotfiles directory
# Returns: Blessed LinkTarget object
sub new {
    my ($class, %args) = @_;

    my $self = bless {
        key             => $args{key},
        ignore          => _to_bool($args{entry}{ignore}, 0),
        ignore_empty    => _to_bool($args{entry}{'ignore-empty'}, 1),
        conflict        => $args{entry}{conflict} // 'skip',
        path            => undef,
        items           => [],
    }, $class;

    # Find the first valid destination path
    $self->_resolve_path($args{entry}{paths}, $args{config_dir});

    # If we found a path, expand the glob and build items
    if ($self->{path}) {
        $self->_build_items($args{config_dir}, $args{entry}{target});
    }

    return $self;
}

# _resolve_path($paths_ref, $config_dir) - Sets $self->{path} to the first
# candidate that exists on the filesystem. Env vars and ~ are expanded first.
# Absolute candidates are checked as-is. Relative candidates are anchored to 
# $config_dir (NOT to the current working directory) so that resolution is
# stable regardless of where symlish was invoked from.
# Params:
#   $paths_ref  - Array ref of candidate destination paths (absolute or relative)
#   $config_ref - Absolute path to the config directory, used as the base for
#                 relative candidates
sub _resolve_path {
    my ($self, $paths_ref, $config_dir) = @_;

    for my $candidate (@$paths_ref) {
        my $expanded = expand_path($candidate);

        my $resolved = File::Spec->file_name_is_absolute($expanded)
            ? $expanded
            : File::Spec->catfile($config_dir, $expanded);

        if (-e $resolved) {
            $self->{path} = $resolved;
            return;
        }
    }
}

# _build_items($config_dir, $target_pattern) - Expands the glob and 
# populates $self->{items}
# Supports both forward configs (relative target, e.g. 'bash/*') and 
# reverse config (absolute target, e.g. /etc/myapp/*). The destination 
# layout differs between the two (see loop below)
# Params:
#   $config_dir     - Absolute path to the config directory
#   $target_pattern - Glob pattern, relative to $config_dir or absolute
sub _build_items {
    my ($self, $config_dir, $target_pattern) = @_;

    my $expanded = expand_path($target_pattern);
    my $is_absolute = File::Spec->file_name_is_absolute($expanded);

    # Base pattern: an absolute pattern is used as-is; a relative pattern is
    # anchored to $config_dir. Both branches use $expanded so env vars and ~
    # are honoured consistently.
    my $base_pattern = $is_absolute
        ? $expanded
        : File::Spec->catfile($config_dir, $expanded);

    # bsd_glob's default doesn't match dotfiles (e.g. ~/.bashrc), so for any pattern
    # containing a literal '*' we also glob a dot-augmented variant ('/*' -> '/.*')
    # and rely on the basename filter below to drop '.' and '..'.
    my @patterns = ($base_pattern);
    if($target_pattern =~ /\*/) {
        my $dot_pattern = $base_pattern;
        $dot_pattern =~ s{/\*}{/.*}g;
        push @patterns, $dot_pattern;
    }

    # Expand, drop '.' and '..', then deduplicate (preserving order)
    my %seen;
    my @sources = grep { !$seen{$_}++ }
                    grep { basename($_) !~ /^\.\.?$/ }
                    map  { bsd_glob($_) } @patterns;

    # Forward config: 'bash/*' globs to e.g. '$config_dir/bash/.bashrc'.
    #   We strip the top-level directory component ('bash') and preserve 
    #   any remaining subtree under $self->{path}
    # Reverse config: '/etc/myapp/*' globs to e.g. '/etc/myapp/foo.conf'.
    #   There is no project-relative subtree to preserve, so we flatten
    #   by basename: each source lands directly under $self->{path}.
    for my $source (@sources) {
        my $dest;
        if($is_absolute) {
            $dest = File::Spec->catfile($self->{path}, basename($source));
        }
        else {
            my $rel = File::Spec->abs2rel($source, $config_dir);
            my @parts = File::Spec->splitdir($rel);
            shift @parts;
            $dest = File::Spec->catfile($self->{path}, @parts);
        }

        push @{ $self->{items} }, Symlish::LinkItem->new(
            source => $source,
            target => $dest,
        )
    }
}

# Accessors - Read-only access to object properties
# key()          - Returns the target identifier (e.g., 'vscode')
# path()         - Returns the resolved destination path (or undef)
# ignore()       - Returns true if this target should be skipped
# ignore_empty() - Returns true if empty files/dirs should be skipped
# conflict()     - Returns conflict resolution strategy ('skip'/'overwrite')
# items()        - Returns list of LinkItem objects
# is_valid()     - Returns true if a valid destination path was found
sub key             { $_[0]->{key} }
sub path            { $_[0]->{path} }
sub ignore          { $_[0]->{ignore} }
sub ignore_empty    { $_[0]->{ignore_empty} }
sub conflict        { $_[0]->{conflict} }
sub items           { @{ $_[0]->{items} } }
sub is_valid        { defined $_[0]->{path} }

# _to_bool($val, $default) - Converts an INI boolean string to 1 or 0.
# Recognised as false: '0', 'false' (case-insensitive), ''.
# Anything else is treated as true. Undef returns $default
# Params:
#   $val     - The string value to convert, or undef
#   $default - Value to return when $val is undef
# Returns: 1 or 0
sub _to_bool {
    my ($val, $default) = @_;

    return $default unless defined $val;
    return 0 if $val eq '0' || $val =~ /^false$/i || $val eq '';
    return 1;
}

# expand_path($raw) - Expands shell-like path tokens.
# Performs two substitutions:
#   1. $VAR is replaced with $ENV{VAR}, or with empty string if unset.
#   2. A leading '~' is replaced with user's home directory ($HOME on
#      POSIX, failing back to $USERPROFILE on Windows where HOME is 
#      usually unset), If neither is set, '~' is left untouched.
# Notes: 
#   1. Unset $VAR collapses to empty string, which can turn a path like
#      '$APPDATA/Code/' into '/Code' on a system without APPDATA. Callers
#      rely on the existence check in _resolve_path to discard such candidates.
#   2. Windows-specific paths (e.g. %APPDATA%) are not supported. Symlish is 
#      indented to be run from minGW or MSYS environments.
# Params:
#   $raw - Path string from config
# Returns: Expanded path string
sub expand_path {
    my ($raw) = @_;

    # Expand environment variables ($HOME, $APPDATA, etc.).
    my $expanded = $raw;
    $expanded =~ s/\$(\w+)/exists $ENV{$1} ? $ENV{$1} : ''/ge;

    # Expand leading ~ to user's home directory
    my $home = $ENV{HOME} // $ENV{USERPROFILE};
    $expanded =~ s/^~/$home/ if defined $home;

    return $expanded;
}

1;