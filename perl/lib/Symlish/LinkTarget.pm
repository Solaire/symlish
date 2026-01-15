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
    $self->_resolve_path($args{entry}{paths});

    # If we found a path, expand the glob and build items
    if ($self->{path}) {
        $self->_build_items($args{config_dir}, $args{entry}{target});
    }

    return $self;
}

# _resolve_path($paths_ref) - Finds first existing destination path.
# Expands environment variables ($HOME, $APPDATA) and ~ in paths.
# Sets $self->{path} to the first path that exists on the system.
# Params:
#   $paths_ref - Array ref of candidate destination paths
sub _resolve_path {
    my ($self, $paths_ref) = @_;

    for my $candidate (@$paths_ref) {
        # Expand environment variables ($HOME, $APPDATA, etc.)
        my $expanded = $candidate;
        $expanded =~ s/\$(\w+)/exists $ENV{$1} ? $ENV{$1} : ''/ge;

        # Expand ~ to home directory
        $expanded =~ s/^~/$ENV{HOME}/;

        # Get absolute path
        my $abs = File::Spec->rel2abs($expanded);

        if (-e $abs) {
            $self->{path} = $abs;
            return;
        }
    }
}

# _build_items($config_dir, $target_pattern) - Expands glob and creates LinkItems.
# Globs the target pattern to find source files, then creates LinkItem
# objects mapping each source to its destination path.
# Params:
#   $config_dir     - Absolute path to dotfiles directory
#   $target_pattern - Glob pattern (e.g., 'bash/**', 'vscode/*')
sub _build_items {
    my ($self, $config_dir, $target_pattern) = @_;

    my $glob_pattern = File::Spec->catfile($config_dir, $target_pattern);

    # bsd_glob with GLOB_CSH handles most cases; we also explicitly glob for dotfiles
    my @matches = bsd_glob($glob_pattern);

    # If pattern doesn't explicitly start with a dot, try matching dotfiles
    # by prepending a dot variant for the last component
    if ($target_pattern =~ /\*/) {
        # Replace * with .* in the last path component to match dotfiles
        my $dot_pattern = $glob_pattern;
        $dot_pattern =~ s{/\*}{/.*}g;
        push @matches, bsd_glob($dot_pattern);
    }

    # Deduplicate
    my %seen;
    @matches = grep { !$seen{$_}++ } @matches;

    for my $source (@matches) {
        # Skip . and ..
        next if basename($source) =~ /^\.\.?$/;

        # Get relative path from config_dir
        my $rel = File::Spec->abs2rel($source, $config_dir);

        # Split the path and drop the first component (the target folder name)
        my @parts = File::Spec->splitdir($rel);
        shift @parts;

        # Build destination path
        my $dest = File::Spec->catfile($self->{path}, @parts);

        push @{ $self->{items} }, Symlish::LinkItem->new(
            source => $source,
            target => $dest,
        );
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

# _to_bool($val, $default) - Converts YAML boolean values to Perl boolean.
# Handles: 0, 1, 'true', 'false', '', undef
# Params:
#   $val     - The value to convert
#   $default - Default if $val is undefined
# Returns: 1 or 0
sub _to_bool {
    my ($val, $default) = @_;

    return $default unless defined $val;
    return 0 if $val eq '0' || $val =~ /^false$/i || $val eq '';
    return 1;
}

1;