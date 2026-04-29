#!/usr/bin/env perl
#
# 07-integration.t - End-to-end integration tests
#
# Tests the full workflow with a complete mock dotfiles setup.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);

use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Symlish::Config qw(load_config);
use Symlish::Targets qw(build_targets filter_targets);
use Symlish::Commands qw(do_link do_unlink do_status);

# Capture STDOUT from a code block using only core modules.
sub _capture {
    my ($code) = @_;
    my $output = '';
    open(my $fh, '>', \$output) or die "Cannot create capture handle: $!";
    my $old = select($fh);
    eval { $code->() };
    my $err = $@;
    select($old);
    die $err if $err;
    return $output;
}

#=============================================================================
# Setup: Create a complete mock dotfiles repository
#=============================================================================
sub create_mock_dotfiles_repo {
    my $root = tempdir(CLEANUP => 1);
    
    # Dotfiles root
    my $dotfiles = File::Spec->catdir($root, 'dotfiles');
    make_path($dotfiles);
    
    # Create bash configs
    my $bash_dir = File::Spec->catdir($dotfiles, 'bash');
    make_path($bash_dir);
    _write_file(File::Spec->catfile($bash_dir, '.bashrc'), <<'BASH');
# ~/.bashrc - Bash configuration
export EDITOR=vim
alias ll='ls -la'
alias gs='git status'

# Load local config if exists
[ -f ~/.bashrc.local ] && source ~/.bashrc.local
BASH

    _write_file(File::Spec->catfile($bash_dir, '.bash_profile'), <<'PROFILE');
# ~/.bash_profile
[[ -f ~/.bashrc ]] && source ~/.bashrc
PROFILE

    # Create git configs
    my $git_dir = File::Spec->catdir($dotfiles, 'git');
    make_path($git_dir);
    _write_file(File::Spec->catfile($git_dir, '.gitconfig'), <<'GIT');
[user]
    name = Test User
    email = test@example.com
[core]
    editor = vim
[alias]
    st = status
    co = checkout
GIT

    # Create vscode configs (with subdirectory)
    my $vscode_dir = File::Spec->catdir($dotfiles, 'vscode');
    make_path($vscode_dir);
    _write_file(File::Spec->catfile($vscode_dir, 'settings.json'), <<'JSON');
{
    "editor.fontSize": 14,
    "editor.tabSize": 4
}
JSON
    _write_file(File::Spec->catfile($vscode_dir, 'keybindings.json'), <<'JSON');
[]
JSON

    # Create an ignored config
    my $emacs_dir = File::Spec->catdir($dotfiles, 'emacs');
    make_path($emacs_dir);
    _write_file(File::Spec->catfile($emacs_dir, '.emacs'), "; Emacs config\n");

    # Create empty file to test ignore-empty
    my $empty_dir = File::Spec->catdir($dotfiles, 'empty');
    make_path($empty_dir);
    _write_file(File::Spec->catfile($empty_dir, 'placeholder.txt'), '');

    # Create mock home directory
    my $home = File::Spec->catdir($root, 'home');
    make_path($home);
    
    # Create mock vscode config directory
    my $vscode_home = File::Spec->catdir($home, '.config', 'Code');
    make_path($vscode_home);
    
    # Write symlish.conf.ini
    _write_file(File::Spec->catfile($dotfiles, 'symlish.conf.ini'), <<"INI");
[bash]
target = bash/*
paths = $home

[git]
target = git/*
paths = $home

[vscode]
target = vscode/*
paths = /nonexistent/windows/path, $vscode_home

[emacs]
target = emacs/*
ignore = true
paths = $home

[empty]
target = empty/*
ignore-empty = true
paths = $home
INI

    return {
        root => $root,
        dotfiles => $dotfiles,
        home => $home,
        vscode_home => $vscode_home,
    };
}

#=============================================================================
# Test: Full link workflow
#=============================================================================
subtest 'Full link workflow' => sub {
    my $mock = create_mock_dotfiles_repo();
    
    # Load config
    my $config = load_config($mock->{dotfiles});
    ok($config, 'Config loaded');
    
    # Build targets
    my @targets = build_targets($config);
    ok(scalar(@targets) >= 4, 'Multiple targets built');
    
    # Link all targets
    for my $target (@targets) {
        next unless $target->is_valid;
        next if $target->ignore;
        
        _capture(sub { do_link($target, { 'dry-run' => 0 }) });
    }
    
    # Verify bash symlinks
    my $bashrc = File::Spec->catfile($mock->{home}, '.bashrc');
    ok(-l $bashrc, '.bashrc symlink created');
    
    my $gitconfig = File::Spec->catfile($mock->{home}, '.gitconfig');
    ok(-l $gitconfig, '.gitconfig symlink created');
    
    # Verify vscode symlinks (should be in vscode_home, not home)
    my $settings = File::Spec->catfile($mock->{vscode_home}, 'settings.json');
    ok(-l $settings, 'settings.json symlink created in vscode config dir');
    
    # Verify emacs NOT linked (ignore: true)
    my $emacs = File::Spec->catfile($mock->{home}, '.emacs');
    ok(!-e $emacs, '.emacs not linked (ignored)');
    
    # Verify empty file not linked (ignore-empty)
    my $empty = File::Spec->catfile($mock->{home}, 'placeholder.txt');
    ok(!-e $empty, 'Empty file not linked (ignore-empty)');
};

#=============================================================================
# Test: Full unlink workflow
#=============================================================================
subtest 'Full unlink workflow' => sub {
    my $mock = create_mock_dotfiles_repo();
    
    my $config = load_config($mock->{dotfiles});
    my @targets = build_targets($config);
    
    # Link first
    for my $target (@targets) {
        next unless $target->is_valid;
        next if $target->ignore;
        _capture(sub { do_link($target, { 'dry-run' => 0 }) });
    }
    
    my $bashrc = File::Spec->catfile($mock->{home}, '.bashrc');
    ok(-l $bashrc, '.bashrc exists before unlink');
    
    # Unlink
    for my $target (@targets) {
        next unless $target->is_valid;
        next if $target->ignore;
        _capture(sub { do_unlink($target, { 'dry-run' => 0 }) });
    }
    
    ok(!-e $bashrc, '.bashrc removed after unlink');
};

#=============================================================================
# Test: Status reporting
#=============================================================================
subtest 'Status reporting' => sub {
    my $mock = create_mock_dotfiles_repo();
    
    my $config = load_config($mock->{dotfiles});
    my @targets = build_targets($config);
    
    # Get bash target
    my ($bash_target) = grep { $_->key eq 'bash' } @targets;
    ok($bash_target, 'Found bash target');
    
    # Status before linking
    my $before = _capture(sub { do_status($bash_target) });
    like($before, qr/not linked/, 'Status shows "not linked" before');
    
    # Link
    _capture(sub { do_link($bash_target, { 'dry-run' => 0 }) });
    
    # Status after linking
    my $after = _capture(sub { do_status($bash_target) });
    like($after, qr/->/, 'Status shows symlink arrow after');
};

#=============================================================================
# Test: Backup and restore cycle
#=============================================================================
subtest 'Backup and restore cycle' => sub {
    my $mock = create_mock_dotfiles_repo();
    
    # Create existing .bashrc
    my $bashrc = File::Spec->catfile($mock->{home}, '.bashrc');
    _write_file($bashrc, "# My original bashrc\necho 'Hello'\n");
    my $original_content = _read_file($bashrc);
    
    my $config = load_config($mock->{dotfiles});
    my @targets = build_targets($config);
    my ($bash_target) = grep { $_->key eq 'bash' } @targets;
    
    # Link (should create backup)
    _capture(sub { do_link($bash_target, { 'dry-run' => 0 }) });
    
    ok(-l $bashrc, '.bashrc is now a symlink');
    ok(-e "$bashrc.bak", 'Backup was created');
    is(_read_file("$bashrc.bak"), $original_content, 'Backup has original content');
    
    # Unlink (should restore backup)
    _capture(sub { do_unlink($bash_target, { 'dry-run' => 0 }) });
    
    ok(-e $bashrc, '.bashrc exists after unlink');
    ok(!-l $bashrc, '.bashrc is not a symlink');
    ok(!-e "$bashrc.bak", 'Backup was removed');
    is(_read_file($bashrc), $original_content, 'Original content restored');
};

#=============================================================================
# Test: Filter with --only option
#=============================================================================
subtest 'Filter with --only' => sub {
    my $mock = create_mock_dotfiles_repo();
    
    my $config = load_config($mock->{dotfiles});
    my @targets = build_targets($config);
    
    # Filter to only bash
    my @filtered = filter_targets(\@targets, { only => ['bash'] });
    
    is(scalar(@filtered), 1, 'Only one target after filter');
    is($filtered[0]->key, 'bash', 'Filtered target is bash');
    
    # Link only bash
    _capture(sub { do_link($filtered[0], { 'dry-run' => 0 }) });
    
    my $bashrc = File::Spec->catfile($mock->{home}, '.bashrc');
    my $gitconfig = File::Spec->catfile($mock->{home}, '.gitconfig');
    
    ok(-l $bashrc, 'bash files linked');
    ok(!-e $gitconfig, 'git files NOT linked (filtered out)');
};

#=============================================================================
# Test: Filter with --ignore option
#=============================================================================
subtest 'Filter with --ignore' => sub {
    my $mock = create_mock_dotfiles_repo();
    
    my $config = load_config($mock->{dotfiles});
    my @targets = build_targets($config);
    
    # Ignore bash
    my @filtered = filter_targets(\@targets, { ignore => ['bash', 'emacs', 'empty'] });
    
    # Link remaining
    for my $target (@filtered) {
        next unless $target->is_valid;
        _capture(sub { do_link($target, { 'dry-run' => 0 }) });
    }
    
    my $bashrc = File::Spec->catfile($mock->{home}, '.bashrc');
    my $gitconfig = File::Spec->catfile($mock->{home}, '.gitconfig');
    
    ok(!-e $bashrc, 'bash NOT linked (ignored)');
    ok(-l $gitconfig, 'git linked');
};

#=============================================================================
# Test: Dry-run doesn't modify filesystem
#=============================================================================
subtest 'Dry-run safety' => sub {
    my $mock = create_mock_dotfiles_repo();
    
    # Create existing file
    my $bashrc = File::Spec->catfile($mock->{home}, '.bashrc');
    _write_file($bashrc, "# Original\n");
    my $original_mtime = (stat($bashrc))[9];
    
    my $config = load_config($mock->{dotfiles});
    my @targets = build_targets($config);
    my ($bash_target) = grep { $_->key eq 'bash' } @targets;
    
    # Dry-run link
    my $out1 = _capture(sub { do_link($bash_target, { 'dry-run' => 1 }) });
    
    ok(-f $bashrc, '.bashrc still a regular file');
    ok(!-l $bashrc, '.bashrc NOT a symlink');
    ok(!-e "$bashrc.bak", 'No backup created');
    like($out1, qr/Would/, 'Output says "Would"');
    
    # Actually link
    _capture(sub { do_link($bash_target, { 'dry-run' => 0 }) });
    ok(-l $bashrc, '.bashrc is now a symlink');
    
    # Dry-run unlink
    my $out2 = _capture(sub { do_unlink($bash_target, { 'dry-run' => 1 }) });
    
    ok(-l $bashrc, '.bashrc still a symlink after dry-run unlink');
    ok(-e "$bashrc.bak", 'Backup still exists');
    like($out2, qr/Would/, 'Unlink output says "Would"');
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
