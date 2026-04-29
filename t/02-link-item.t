#!/usr/bin/env perl
#
# 02-link-item.t - Tests for Symlish::LinkItem module
#
# Tests individual symlink operations: creation, removal, backup, restore.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path remove_tree);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Symlish::LinkItem;

#=============================================================================
# Test: Constructor creates object with correct attributes
#=============================================================================
subtest 'Constructor' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    # Create source file
    _write_file($source, "test content");
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    isa_ok($item, 'Symlish::LinkItem');
    is($item->source, $source, 'source accessor works');
    is($item->target, $target, 'target accessor works');
    is($item->backup, "$target.bak", 'backup path is target + .bak');
    is($item->type, 'file', 'type is file for regular file');
};

#=============================================================================
# Test: Type detection for directories
#=============================================================================
subtest 'Type detection for directories' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source_dir = File::Spec->catdir($tempdir, 'source_dir');
    my $target = File::Spec->catfile($tempdir, 'target');
    
    make_path($source_dir);
    
    my $item = Symlish::LinkItem->new(
        source => $source_dir,
        target => $target,
    );
    
    is($item->type, 'directory', 'type is directory for directories');
};

#=============================================================================
# Test: is_here - symlink pointing to correct source
#=============================================================================
subtest 'is_here detection' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    _write_file($source, "test");
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    # No link yet
    ok(!$item->is_here, 'is_here returns false when no link exists');
    
    # Create symlink to our source
    symlink($source, $target);
    ok($item->is_here, 'is_here returns true when link points to source');
    
    # Create symlink to different target
    unlink($target);
    my $other = File::Spec->catfile($tempdir, 'other.txt');
    _write_file($other, "other");
    symlink($other, $target);
    ok(!$item->is_here, 'is_here returns false when link points elsewhere');
};

#=============================================================================
# Test: is_symlink detection
#=============================================================================
subtest 'is_symlink detection' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    _write_file($source, "test");
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    ok(!$item->is_symlink, 'is_symlink false when target does not exist');
    
    # Create regular file at target
    _write_file($target, "regular file");
    ok(!$item->is_symlink, 'is_symlink false for regular files');
    
    # Replace with symlink
    unlink($target);
    symlink($source, $target);
    ok($item->is_symlink, 'is_symlink true for symlinks');
};

#=============================================================================
# Test: Backup operations
#=============================================================================
subtest 'Backup operations' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    _write_file($source, "source content");
    _write_file($target, "original target content");
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    # Before backup
    ok(!$item->has_backup, 'has_backup false before backup');
    ok($item->can_backup, 'can_backup true for regular files');
    
    # Create backup
    $item->create_backup;
    ok($item->has_backup, 'has_backup true after backup');
    ok(!-e $target, 'target file was renamed');
    ok(-e $item->backup, 'backup file exists');
    is(_read_file($item->backup), "original target content", 
        'backup has original content');
};

#=============================================================================
# Test: cannot backup symlinks
#=============================================================================
subtest 'Cannot backup symlinks' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    my $other = File::Spec->catfile($tempdir, 'other.txt');
    
    _write_file($source, "source");
    _write_file($other, "other");
    symlink($other, $target);
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    ok(!$item->can_backup, 'can_backup false for symlinks');
};

#=============================================================================
# Test: Restore backup
#=============================================================================
subtest 'Restore backup' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    _write_file($source, "source");
    _write_file($target, "original");
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    # Create backup, then restore
    $item->create_backup;
    ok(!-e $target, 'target gone after backup');
    
    $item->restore_backup;
    ok(-e $target, 'target restored');
    ok(!-e $item->backup, 'backup file removed');
    is(_read_file($target), "original", 'restored content is correct');
};

#=============================================================================
# Test: Create symlink
#=============================================================================
subtest 'Create symlink' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    _write_file($source, "source content");
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    ok(!-e $target, 'target does not exist initially');
    
    $item->create_symlink;
    
    ok(-l $target, 'target is now a symlink');
    is(readlink($target), $source, 'symlink points to source');
    ok($item->is_here, 'is_here returns true after create_symlink');
};

#=============================================================================
# Test: Remove symlink
#=============================================================================
subtest 'Remove symlink' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $source = File::Spec->catfile($tempdir, 'source.txt');
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    _write_file($source, "source");
    symlink($source, $target);
    
    my $item = Symlish::LinkItem->new(
        source => $source,
        target => $target,
    );
    
    ok(-l $target, 'symlink exists');
    
    $item->remove_symlink;
    
    ok(!-e $target, 'symlink removed');
    ok(-e $source, 'source still exists');
};

#=============================================================================
# Test: is_source_empty for files
#=============================================================================
subtest 'is_source_empty for files' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $target = File::Spec->catfile($tempdir, 'target.txt');
    
    # Empty file
    my $empty_source = File::Spec->catfile($tempdir, 'empty.txt');
    _write_file($empty_source, "");
    
    my $item1 = Symlish::LinkItem->new(
        source => $empty_source,
        target => $target,
    );
    ok($item1->is_source_empty, 'Empty file detected as empty');
    
    # Non-empty file
    my $nonempty_source = File::Spec->catfile($tempdir, 'nonempty.txt');
    _write_file($nonempty_source, "content");
    
    my $item2 = Symlish::LinkItem->new(
        source => $nonempty_source,
        target => $target,
    );
    ok(!$item2->is_source_empty, 'Non-empty file not detected as empty');
};

#=============================================================================
# Test: is_source_empty for directories
#=============================================================================
subtest 'is_source_empty for directories' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $target = File::Spec->catfile($tempdir, 'target');
    
    # Empty directory
    my $empty_dir = File::Spec->catdir($tempdir, 'empty_dir');
    make_path($empty_dir);
    
    my $item1 = Symlish::LinkItem->new(
        source => $empty_dir,
        target => $target,
    );
    ok($item1->is_source_empty, 'Empty directory detected as empty');
    
    # Non-empty directory
    my $nonempty_dir = File::Spec->catdir($tempdir, 'nonempty_dir');
    make_path($nonempty_dir);
    _write_file(File::Spec->catfile($nonempty_dir, 'file.txt'), "content");
    
    my $item2 = Symlish::LinkItem->new(
        source => $nonempty_dir,
        target => $target,
    );
    ok(!$item2->is_source_empty, 'Non-empty directory not detected as empty');
};

#=============================================================================
# Helpers
#=============================================================================
sub _write_file {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print $fh $content;
    close $fh;
}

sub _read_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read $path: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

done_testing();
