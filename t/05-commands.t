#!/usr/bin/env perl
#
# 05-commands.t - Tests for Symlish::Commands module
#
# Integration tests for link, unlink, and status commands.
# Uses a mock dotfiles directory structure.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path remove_tree);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use lib "$RealBin/lib";

use Symlish::LinkTarget;
use Symlish::Commands qw(do_apply do_clean do_status);
use SymlishTest qw(capture);

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
    _write_file(File::Spec->catfile($bash_dir, '.bashrc'), 
        "# My bashrc\nalias ll='ls -la'\n");
    _write_file(File::Spec->catfile($bash_dir, '.bash_profile'), 
        "# Bash profile\n");
    _write_file(File::Spec->catfile($bash_dir, 'empty.txt'), '');
    
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
    _write_file($existing_bashrc, "# Original bashrc content\n");
    
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
    like(_read_file($backup), qr/Original bashrc/, 'Backup has original content');
    
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
    _write_file($bashrc, "# Original content\n");
    
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
    like(_read_file($bashrc), qr/Original content/, 'Original content restored');
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
# Test: do_status shows link status
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
    like($stdout2, qr/->/, 'Shows arrow indicating symlink');
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
    
    # Second run should be quiet (links already exist)
    my $bashrc_link = File::Spec->catfile($home, '.bashrc');
    ok(-l $bashrc_link, 'Symlink still exists');
    
    # Count symlinks (should still be same)
    is(readlink($bashrc_link), 
        File::Spec->catfile($dotfiles, 'bash', '.bashrc'),
        'Symlink unchanged after re-run');
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
