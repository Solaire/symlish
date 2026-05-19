#!/usr/bin/env perl
#
# 05-commands.t - Tests for Symlish::Commands module
#
# Integration tests for apply, clean, and status commands.
# Uses a mock dotfiles directory structure.

use strict;
use warnings;

use Test::More;

use File::Spec;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use lib "$RealBin/lib";

use Symlish::LinkTarget;
use Symlish::Commands qw(do_apply do_clean do_status);
use SymlishTest qw(capture write_file read_file);

#=============================================================================
# Setup: Create a mock dotfiles structure
#=============================================================================
sub setup_mock_dotfiles {
    my $root = tempdir(CLEANUP => 1);
    
    # Create dotfiles source directory
    my $dotfiles = File::Spec->catdir($root, 'dotfiles');
    my $bash_dir = File::Spec->catdir($dotfiles, 'bash');
    make_path($bash_dir);
    
    # Create some dotfiles
    write_file(File::Spec->catfile($bash_dir, '.bashrc'), 
        "# My bashrc\nalias ll='ls -la'\n");
    write_file(File::Spec->catfile($bash_dir, '.bash_profile'), 
        "# Bash profile\n");
    write_file(File::Spec->catfile($bash_dir, 'empty.txt'), '');
    
    # Create destination directory (simulating home)
    my $home = File::Spec->catdir($root, 'home');
    make_path($home);
    
    return ($root, $dotfiles, $home);
}

#=============================================================================
# Test: do_apply creates symlinks
#=============================================================================
subtest 'do_apply creates symlinks' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    my $options = { 'dry-run' => 0 };
    
    # Capture output
    my $stdout = capture(sub {
        do_apply($target, $options);
    });
    
    # Check symlinks were created
    my $bashrc_link = File::Spec->catfile($home, '.bashrc');
    ok(-l $bashrc_link, '.bashrc symlink created');
    is(readlink($bashrc_link), 
        File::Spec->catfile($dotfiles, 'bash', '.bashrc'),
        '.bashrc points to source');
    
    my $profile_link = File::Spec->catfile($home, '.bash_profile');
    ok(-l $profile_link, '.bash_profile symlink created');
};

#=============================================================================
# Test: do_apply dry-run mode
#=============================================================================
subtest 'do_apply dry-run mode' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    my $options = { 'dry-run' => 1 };
    
    # Capture output
    my $stdout = capture(sub {
        do_apply($target, $options);
    });
    
    # Check symlinks were NOT created
    my $bashrc_link = File::Spec->catfile($home, '.bashrc');
    ok(!-e $bashrc_link, 'No symlink created in dry-run mode');
    
    # Check output mentions "Would link"
    like($stdout, qr/Would link/, 'Dry-run output shows "Would link"');
};

#=============================================================================
# Test: do_apply creates backup of existing files
#=============================================================================
subtest 'do_apply creates backup' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    # Create existing .bashrc in home
    my $existing_bashrc = File::Spec->catfile($home, '.bashrc');
    write_file($existing_bashrc, "# Original bashrc content\n");
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    my $options = { 'dry-run' => 0 };
    
    capture(sub { do_apply($target, $options) });
    
    # Check backup was created
    my $backup = "$existing_bashrc.bak";
    ok(-e $backup, 'Backup file created');
    like(read_file($backup), qr/Original bashrc/, 'Backup has original content');
    
    # Check new symlink exists
    ok(-l $existing_bashrc, '.bashrc is now a symlink');
};

#=============================================================================
# Test: do_apply skips empty files with ignore-empty
#=============================================================================
subtest 'do_apply skips empty files' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
            'ignore-empty' => 'true',
        },
        config_dir => $dotfiles,
    );
    
    my $options = { 'dry-run' => 0 };
    
    my $stdout = capture(sub { do_apply($target, $options) });
    
    # empty.txt should be skipped
    my $empty_link = File::Spec->catfile($home, 'empty.txt');
    ok(!-e $empty_link, 'Empty file not linked');
    like($stdout, qr/Skipping empty/, 'Output mentions skipping empty');
};

#=============================================================================
# Test: do_clean removes symlinks
#=============================================================================
subtest 'do_clean removes symlinks' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    my $options = { 'dry-run' => 0 };
    
    # First, create the links
    capture(sub { do_apply($target, $options) });
    
    my $bashrc_link = File::Spec->catfile($home, '.bashrc');
    ok(-l $bashrc_link, 'Symlink exists before clean');
    
    # Now clean
    capture(sub { do_clean($target, $options) });
    
    ok(!-e $bashrc_link, 'Symlink removed after clean');
};

#=============================================================================
# Test: do_clean restores backups
#=============================================================================
subtest 'do_clean restores backups' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    # Create existing .bashrc
    my $bashrc = File::Spec->catfile($home, '.bashrc');
    write_file($bashrc, "# Original content\n");
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    my $options = { 'dry-run' => 0 };
    
    # Apply (creates backup)
    capture(sub { do_apply($target, $options) });
    ok(-e "$bashrc.bak", 'Backup created');
    
    # Clean (restores backup)
    capture(sub { do_clean($target, $options) });
    
    ok(-e $bashrc, '.bashrc restored');
    ok(!-l $bashrc, '.bashrc is a regular file, not symlink');
    ok(!-e "$bashrc.bak", 'Backup removed');
    like(read_file($bashrc), qr/Original content/, 'Original content restored');
};

#=============================================================================
# Test: do_clean dry-run mode
#=============================================================================
subtest 'do_clean dry-run mode' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    # Create links first
    capture(sub { do_apply($target, { 'dry-run' => 0 }) });
    
    my $bashrc_link = File::Spec->catfile($home, '.bashrc');
    ok(-l $bashrc_link, 'Symlink exists');
    
    # Dry-run clean
    my $stdout = capture(sub { do_clean($target, { 'dry-run' => 1 }) });
    
    ok(-l $bashrc_link, 'Symlink still exists after dry-run');
    like($stdout, qr/Would unlink/, 'Dry-run output shows "Would unlink"');
};

#=============================================================================
# Test: do_status shows status
#=============================================================================
subtest 'do_status shows status' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    # Status before linking
    my $stdout1 = capture(sub { do_status($target) });
    like($stdout1, qr/not linked/, 'Shows "not linked" before linking');
    
    # Apply
    capture(sub { do_apply($target, { 'dry-run' => 0 }) });
    
    # Status after linking
    my $stdout2 = capture(sub { do_status($target) });
    like($stdout2, qr{\S+\s*->\s*\S+}, 'Shows <target> -> <source> arrow');
};

#=============================================================================
# Test: do_apply skips if already linked
#=============================================================================
subtest 'do_apply skips already linked' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();
    
    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target => 'bash/*',
            paths => [$home],
        },
        config_dir => $dotfiles,
    );
    
    my $options = { 'dry-run' => 0 };
    
    # Apply twice
    capture(sub { do_apply($target, $options) });
    my $stdout2 = capture(sub { do_apply($target, $options) });
    
    # Second run should be silent; every file hits the `is_here` early exit
    # in do_apply, so no "Linked" / "Backed up" / "Conflict" output is emitted.
    unlike($stdout2, qr/Linked|Backed up|Conflict/,
        'Second run produces no link/backup/conflict output');

    my $bashrc_link = File::Spec->catfile($home, '.bashrc');
    ok(-l $bashrc_link, 'Symlink still exists');

    # Count symlinks (should still be same)
    is(readlink($bashrc_link),
        File::Spec->catfile($dotfiles, 'bash', '.bashrc'),
        'Symlink unchanged after re-run');
};

#=============================================================================
# Test: do_apply with "conflict = overwrite" replaces foreign symlinks
#=============================================================================
# Preexisting symlink that points somewhere other than our source. With
# "conflict = overwrite", do_apply should drop it and re-link to our source.
subtest 'do_apply with "conflict = overwrite"' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();

    # Plant a symlink at the destination pointing at an unrelated file.
    my $bashrc  = File::Spec->catfile($home, '.bashrc');
    my $foreign = File::Spec->catfile($home, 'foreign.txt');
    write_file($foreign, "not ours");
    symlink($foreign, $bashrc) or die "symlink failed: $!";

    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target   => 'bash/*',
            paths    => [$home],
            conflict => 'overwrite',
        },
        config_dir => $dotfiles,
    );

    my $stdout = capture( sub { do_apply($target, { 'dry-run' => 0 }) });
    like($stdout, qr/Overwriting conflict/, 'Output mentions overwriting');
    ok(-l $bashrc, '.bashrc is still a symlink');
    is(readlink($bashrc), File::Spec->catfile($dotfiles, 'bash', '.bashrc'), 
        '.bashrc now points to our source');
};


#=============================================================================
# Test: do_apply with "conflict = skip" leaves foreign symlinks alone
#=============================================================================
# Same setup as above, but "conflict = skip" should leave the pre-existing
# symlink intact.
subtest 'do_apply with "conflict = skip"' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();

    # Plant a symlink at the destination pointing at an unrelated file.
    my $bashrc  = File::Spec->catfile($home, '.bashrc');
    my $foreign = File::Spec->catfile($home, 'foreign.txt');
    write_file($foreign, "not ours");
    symlink($foreign, $bashrc) or die "symlink failed: $!";

    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target   => 'bash/*',
            paths    => [$home],
            # conflict omitted -> defaults to 'skip'
        },
        config_dir => $dotfiles,
    );

    my $stdout = capture( sub { do_apply($target, { 'dry-run' => 0 }) });
    like($stdout, qr/Conflict.*symlink exists, skipping/, 
        'Output reports conflict and the skip');
    ok(-l $bashrc, '.bashrc is still a symlink');
    is(readlink($bashrc), $foreign, '.bashrc still points to the foreign source');
};

#=============================================================================
# Test: do_apply with 'ignore-empty = false' links the empty file
#=============================================================================
# setup_mock_dotfiles() already creates an empty.txt in the bash dir. 
# 'ignore-empty' defaults to true, so that case is covered in other tests. We 
# need to flip the flag and verify that empty file is linked.
subtest 'do_apply with "ignore-empty = false"' => sub {
    my ($root, $dotfiles, $home) = setup_mock_dotfiles();

    my $target = Symlish::LinkTarget->new(
        key => 'bash',
        entry => {
            target         => 'bash/*',
            paths          => [$home],
            'ignore-empty' => 'false',
        },
        config_dir => $dotfiles,
    );

    my $stdout = capture( sub { do_apply($target, { 'dry-run' => 0 }) });
    my $empty_link = File::Spec->catfile($home, 'empty.txt');

    ok(-l $empty_link, 'empty.txt IS linked when "ignore-empty = false"');
    unlike($stdout, qr/Skipping empty/,
        'No "Skipping empty" output when "ignore-empty = false"');
};

done_testing();
