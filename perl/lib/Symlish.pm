package Symlish;

use strict;
use warnings;
use v5.16;

our $VERSION = '0.2.0';

1;

__END__

=head1 NAME

Symlish - Symbolic link manager for dotfiles

=head1 SYNOPSIS

    use Symlish::App;
    Symlish::App->run(@ARGV);

=head1 DESCRIPTION

Symlish is a command-line tool that helps you manage symbolic links for your
dotfiles in a clean, reversible way. It reads a YAML configuration file from
your dotfiles directory and creates/removes symlinks accordingly.

=head1 AUTHOR

Your Name

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
