package Symlish::LinkTarget;

use strict;
use warnings;
use v5.16;

use Cwd qw(abs_path);
use File::Spec;
use File::Basename qw(basename);
use File::Glob qw(bsd_glob);

=head1 NAME

Symlish::LinkTarget - Represents a group of symlink targets

=head1 SYNOPSIS

    use Symlish::LinkTarget;
    
    my $target = Symlish::LinkTarget->new(
        key        => 'vscode',
        entry      => { target => 'vscode/*', paths => ['~/.config/Code'] },
        config_dir => '/path/to/dotfiles',
    );

=head1 DESCRIPTION

A LinkTarget represents a named group of files/directories from your dotfiles
that should be symlinked to a specific destination path.

=cut

sub new {
    my ($class, %args) = @_;

    my $self = bless {
        key          => $args{key},
        ignore       => _to_bool($args{entry}{ignore}, 0),
        ignore_empty => _to_bool($args{entry}{'ignore-empty'}, 1),
        conflict     => $args{entry}{conflict} // 'skip',
        path         => undef,
        items        => [],
    }, $class;

    # Find the first valid destination path
    $self->_resolve_path($args{entry}{paths});

    # If we found a path, expand the glob and build items
    if ($self->{path}) {
        $self->_build_items($args{config_dir}, $args{entry}{target});
    }

    return $self;
}

# Convert YAML boolean values to Perl boolean
sub _to_bool {
    my ($val, $default) = @_;
    return $default unless defined $val;
    return 0 if $val eq '0' || $val =~ /^false$/i || $val eq '';
    return 1;
}

sub _resolve_path {
    my ($self, $paths) = @_;

    for my $candidate (@$paths) {
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

sub _build_items {
    my ($self, $config_dir, $target_pattern) = @_;

    my $glob_pattern = File::Spec->catfile($config_dir, $target_pattern);

    # bsd_glob with GLOB_CSH handles most cases; we also explicitly glob for dotfiles
    my @matches = bsd_glob($glob_pattern);
    
    # If the pattern doesn't explicitly start with a dot, also try matching dotfiles
    # by prepending a dot variant for the last component
    if ($target_pattern =~ /\*/) {
        # Replace * with .* in the last path component to match dotfiles
        my $dot_pattern = $glob_pattern;
        $dot_pattern =~ s{/\*}{/.*}g;
        push @matches, bsd_glob($dot_pattern);
    }
    
    # Deduplicate matches
    my %seen;
    @matches = grep { !$seen{$_}++ } @matches;

    for my $source (@matches) {
        # Skip . and ..
        next if basename($source) =~ /^\.\.?$/;

        # Calculate relative path from config_dir
        my $rel = File::Spec->abs2rel($source, $config_dir);

        # Split the path and drop the first component (the target folder name)
        my @parts = File::Spec->splitdir($rel);
        shift @parts;  # Remove first directory component

        # Build destination path
        my $dest = File::Spec->catfile($self->{path}, @parts);

        push @{ $self->{items} }, Symlish::LinkItem->new(
            source => $source,
            target => $dest,
        );
    }
}

# Accessors
sub key          { $_[0]->{key} }
sub path         { $_[0]->{path} }
sub ignore       { $_[0]->{ignore} }
sub ignore_empty { $_[0]->{ignore_empty} }
sub conflict     { $_[0]->{conflict} }
sub items        { @{ $_[0]->{items} } }
sub is_valid     { defined $_[0]->{path} }

1;

# ============================================================================
# Symlish::LinkItem - Individual symlink item
# ============================================================================

package Symlish::LinkItem;

use strict;
use warnings;
use v5.16;

=head1 NAME

Symlish::LinkItem - Represents a single symlink operation

=cut

sub new {
    my ($class, %args) = @_;

    return bless {
        source => $args{source},
        target => $args{target},
        backup => "$args{target}.bak",
        type   => (-d $args{source} ? 'directory' : 'file'),
    }, $class;
}

# Accessors
sub source { $_[0]->{source} }
sub target { $_[0]->{target} }
sub backup { $_[0]->{backup} }
sub type   { $_[0]->{type} }

# Check if the symlink points to our source
sub is_here {
    my ($self) = @_;
    return 0 unless -l $self->{target};
    return readlink($self->{target}) eq $self->{source};
}

# Check if target is a symlink (possibly pointing elsewhere)
sub is_symlink {
    my ($self) = @_;
    return -l $self->{target};
}

# Check if backup file exists
sub has_backup {
    my ($self) = @_;
    return -e $self->{backup};
}

# Check if we can make a backup (target is a regular file, not a symlink)
sub can_backup {
    my ($self) = @_;
    return -f $self->{target} && !-l $self->{target};
}

# Check if source is empty (empty file or empty directory)
sub is_source_empty {
    my ($self) = @_;
    my $path = $self->{source};

    return 1 if -f $path && -z $path;  # Empty file

    if (-d $path) {
        opendir(my $dh, $path) or return 0;
        my @entries = grep { $_ !~ /^\.\.?$/ } readdir($dh);
        closedir($dh);
        return @entries == 0;
    }

    return 0;
}

# Create backup of existing file
sub create_backup {
    my ($self) = @_;
    return unless $self->can_backup && !$self->has_backup;
    rename $self->{target}, $self->{backup}
        or die "Failed to create backup: $!";
}

# Restore backup
sub restore_backup {
    my ($self) = @_;
    return unless $self->has_backup;
    rename $self->{backup}, $self->{target}
        or die "Failed to restore backup: $!";
}

# Create the symlink
sub create_symlink {
    my ($self) = @_;
    symlink $self->{source}, $self->{target}
        or die "Failed to create symlink: $!";
}

# Remove the symlink
sub remove_symlink {
    my ($self) = @_;
    unlink $self->{target}
        or die "Failed to remove symlink: $!";
}

1;

__END__

=head1 METHODS

=head2 LinkTarget Methods

=over 4

=item new(%args)

Create a new LinkTarget. Required args: key, entry, config_dir.

=item key, path, ignore, ignore_empty, conflict

Accessors for the respective attributes.

=item items

Returns list of LinkItem objects.

=item is_valid

Returns true if a valid destination path was found.

=back

=head2 LinkItem Methods

=over 4

=item is_here

True if the symlink exists and points to our source.

=item is_symlink

True if the target is any symlink.

=item has_backup

True if a backup file exists.

=item can_backup

True if the target can be backed up (regular file, not symlink).

=item is_source_empty

True if the source file/directory is empty.

=item create_backup, restore_backup, create_symlink, remove_symlink

Perform the respective operations.

=back

=cut
