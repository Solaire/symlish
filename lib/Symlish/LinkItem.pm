package Symlish::LinkItem;

use strict;
use warnings;

# Symlish::LinkItem - Represents a single symlink operation.
# Each LinkItem maps one source file/directory to one target location.

# new(%args) - Constructor for LinkItem.
# Params (via %args):
#   source - Absolute path to the file/directory the symlink will point AT.
#   target - Absolute path where the symlink itself will be created.
# Returns: Blessed LinkItem object
sub new {
    my ($class, %args) = @_;

    return bless {
        source => $args{source},
        target => $args{target},
        backup => "$args{target}.bak",
        type   => (-d $args{source} ? 'directory' : 'file'),
    }, $class;
}

# Accessors - Read-only access to object properties.
# source() - Absolute path that the symlink points at
# target() - Absolute path where the symlink lives (or will live)
# backup() - Path of the saved-aside original at $target.bak
# type()   - 'file' or 'directory', based on the source at construction time
sub source { $_[0]->{source} }
sub target { $_[0]->{target} }
sub backup { $_[0]->{backup} }
sub type   { $_[0]->{type}   }

# is_here() - Checks if symlink exists and points to our source.
# Returns: True if target is a symlink pointing to $self->source
sub is_here {
    my ($self) = @_;
    return 0 unless -l $self->{target};
    return readlink($self->{target}) eq $self->source;
}

# is_symlink() - Checks if target path is any symlink.
# Returns: True if target is a symlink (regardless of where it points)
sub is_symlink {
    my ($self) = @_;
    return -l $self->{target};
}

# has_backup() - Checks if a backup file exists for this target.
# Returns: True if {target}.bak exists
sub has_backup {
    my ($self) = @_;
    return -e $self->{backup};
}

# can_backup() - Checks if target can be backed up.
# Only regular files (not symlinks or directories) can be backed up.
# Returns: True if target is a regular file and not a symlink
sub can_backup {
    my ($self) = @_;
    return -f $self->{target} && !-l $self->{target};
}

# is_source_empty() - Checks if source file/directory is empty.
# Empty means: zero-byte file OR directory with no entries.
# Returns: True if source is empty
sub is_source_empty {
    my ($self) = @_;
    return 1 if -f $self->{source} && -z $self->{source}; # Empty file

    if (-d $self->{source}) {
        opendir(my $dh, $self->{source}) or return 0;
        my @entries = grep { !/^\.{1,2}$/ } readdir($dh);
        closedir($dh);
        return @entries == 0;
    }

    return 0;
}

# create_backup() - Renames target to target.bak.
# Only acts if can_backup() is true and no backup exists.
# Dies: If rename fails
sub create_backup {
    my ($self) = @_;
    return unless $self->can_backup && !$self->has_backup;
    rename $self->{target}, $self->{backup}
        or die "Failed to create backup: $!";
}

# restore_backup() - Renames target.bak back to target.
# Only acts if backup exists.
# Dies: If rename fails
sub restore_backup {
    my ($self) = @_;
    return unless $self->has_backup;
    rename $self->{backup}, $self->{target}
        or die "Failed to restore backup: $!";
}

# create_symlink() - Creates a symlink at $self->target pointing to
#   $self->source. Mirrors the syscall ordering: symlink(SRC, LINK).
# Dies: If symlink creation fails
sub create_symlink {
    my ($self) = @_;
    symlink $self->{source}, $self->{target}
        or die "Failed to create symlink: $!";
}

# remove_symlink() - Deletes the symlink at target path.
# Dies: If unlink fails
sub remove_symlink {
    my ($self) = @_;
    unlink $self->{target}
        or die "Failed to remove symlink: $!";
}

1;