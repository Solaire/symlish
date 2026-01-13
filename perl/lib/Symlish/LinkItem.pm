package Symlish::LinkItem;

use strict;
use warnings;

# use Cwd qw(abs_path);
# use File::Spec;
# use File::Basename qw(basename);
# use File::Glob qw(bsd_glob);

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
sub type   { $_[0]->{type}   }

# Check if symlink points to our source
sub is_here {
    my ($self) = @_;
    return 0 unless -l $self->{target};
    return readlink($self->{target}) eq $self->source;
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

# Check if source is empty (empty file or directory)
sub is_source_empty {
    my ($self) = @_;
    return 1 if -f $self->{source} && -z $self->{source}; # Empty file

    if (-d $self->{source}) {
        opendir(my $dh, $self->{source}) or return 0;
        my @entries = grep { $_ !~ /^\.\.$/ } readdir($dh);
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
        or die "Failed to create backup $!";
}

# Restore backup
sub restore_backup {
    my ($self) = @_;
    return unless $self->has_backup;
    rename $self->{backup}, $self->{target}
        or die "Failed to restore backup $!";
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