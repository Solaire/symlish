package Symlish::App;

use strict;
use warnings;
use v5.16;

use Getopt::Long qw(GetOptionsFromArray :config pass_through);
use Cwd qw(abs_path);

use Symlish::Config qw(load_config);
use Symlish::LinkTarget;
use Symlish::Commands qw(do_link do_unlink do_status);

=head1 NAME

Symlish::App - Main application class for Symlish

=head1 SYNOPSIS

    use Symlish::App;
    Symlish::App->run(@ARGV);

=head1 DESCRIPTION

Orchestrates the Symlish command-line tool: parses arguments, loads
configuration, builds targets, and dispatches commands.

=cut

my $USAGE = <<'USAGE';
Usage: symlish <command> <directory> [options]

Commands:
    link      Create symlinks from dotfiles to system locations
    unlink    Remove symlinks and restore backups
    status    Show current symlink status
    help      Display this help message

Options:
    --dry-run           Simulate without making changes
    --ignore  x,y,z     Comma-separated list of targets to skip
    --only    x,y,z     Process only these targets (mutually exclusive with --ignore)

Examples:
    symlish link ~/dotfiles --dry-run
    symlish status ~/dotfiles
    symlish unlink ~/dotfiles --only git,bash
USAGE

sub run {
    my ($class, @argv) = @_;

    # Parse command and directory first
    my $command   = shift @argv;
    my $directory = shift @argv;

    # Handle help or missing args
    if (!$command || $command eq 'help' || $command eq '--help' || $command eq '-h') {
        print $USAGE;
        return 0;
    }

    unless ($directory) {
        die "Error: Missing <directory> argument\n\n$USAGE";
    }

    unless (-d $directory) {
        die "Error: '$directory' is not a valid directory\n";
    }

    unless ($command =~ /^(?:link|unlink|status)$/) {
        die "Error: Unknown command '$command'\n\n$USAGE";
    }

    # Parse options
    my %options = ('dry-run' => 0);
    GetOptionsFromArray(
        \@argv,
        'dry-run'  => \$options{'dry-run'},
        'ignore=s' => \$options{ignore},
        'only=s'   => \$options{only},
    ) or die $USAGE;

    # Validate mutually exclusive options
    if ($options{ignore} && $options{only}) {
        die "Error: --ignore and --only are mutually exclusive\n";
    }

    # Convert comma-separated strings to arrays
    for my $key (qw(ignore only)) {
        if (defined $options{$key}) {
            $options{$key} = [ split /\s*,\s*/, $options{$key} ];
        }
    }

    # Load configuration
    my $config = load_config($directory);

    # Build targets from config
    my @targets = _build_targets($config);

    # Filter targets based on options
    @targets = _filter_targets(\@targets, \%options);

    # Process each target
    for my $target (@targets) {
        print "💎 Processing: ${\$target->key}\n";

        unless ($target->is_valid) {
            print "   ⚠️  Skipping: no valid destination path found\n";
            next;
        }

        if ($target->ignore) {
            print "   ⚠️  Skipping: ignore flag is set\n";
            next;
        }

        # Dispatch to appropriate command handler
        if    ($command eq 'link')   { do_link($target, \%options) }
        elsif ($command eq 'unlink') { do_unlink($target, \%options) }
        elsif ($command eq 'status') { do_status($target) }
    }

    print "🏁 Done.\n";
    return 0;
}

sub _build_targets {
    my ($config) = @_;

    my @targets;
    while (my ($key, $entry) = each %{ $config->{link} }) {
        push @targets, Symlish::LinkTarget->new(
            key        => $key,
            entry      => $entry,
            config_dir => $config->{config_dir},
        );
    }

    return @targets;
}

sub _filter_targets {
    my ($targets, $options) = @_;

    if ($options->{only}) {
        my %only = map { $_ => 1 } @{ $options->{only} };
        return grep { $only{ $_->key } } @$targets;
    }

    if ($options->{ignore}) {
        my %ignore = map { $_ => 1 } @{ $options->{ignore} };
        return grep { !$ignore{ $_->key } } @$targets;
    }

    return @$targets;
}

1;

__END__

=head1 METHODS

=head2 run(@argv)

Main entry point. Parses command line arguments, loads configuration, and
executes the requested command. Returns 0 on success.

=head1 COMMANDS

=over 4

=item link

Create symlinks for all configured targets. Backs up existing files.

=item unlink

Remove symlinks created by this tool and restore backups.

=item status

Show current state of all configured symlinks.

=item help

Display usage information.

=back

=cut
