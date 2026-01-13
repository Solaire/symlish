#!/usr/bin/env bash

# Source - https://stackoverflow.com/questions/2980297/how-can-i-use-cpan-as-a-non-root-user
# Posted by Chas. Owens, modified by community. See post 'Timeline' for change history
# Retrieved 2026-01-04, License - CC BY-SA 4.0

wget -O- http://cpanmin.us | perl - -l ~/perl5 App::cpanminus local::lib
eval `perl -I ~/perl5/lib/perl5 -Mlocal::lib`
echo 'eval `perl -I ~/perl5/lib/perl5 -Mlocal::lib`' >> ~/.bashrc
echo 'export MANPATH=$HOME/perl5/man:$MANPATH' >> ~/.bashrc

# Install dependencies with `cpanm --installdeps .`