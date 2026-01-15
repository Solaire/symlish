#!/usr/bin/env bash
#
# build-docker.sh - Set up a Debian container for Symlish end-to-end tests
#
# This script sets up a small Debian docker container with full Perl installation
# as well as some essential tools (wget, make, etc.). This is to test bootstrapping 
# and installation in a clean Linux environment.
#

set -e

# Colors for output
GREEN='\e[32m\n'
NC='\e[0m'

echo -e ${GREEN}"==> Building test Docker container ..."${NC}
docker build -t symlish-test .

echo -e ${GREEN}"==> Running end-to-end tests in container ..."${NC}
docker run --rm symlish-test bash -c '
    set -e

    ./scripts/install.sh
    
    # Source bashrc in a way that works in non-interactive shell
    export PATH="$HOME/perl5/bin:$PATH"
    export PERL5LIB="$HOME/perl5/lib/perl5:$PERL5LIB"
    export PERL_LOCAL_LIB_ROOT="$HOME/perl5:$PERL_LOCAL_LIB_ROOT"
    
    cpanm --installdeps .
    make test
    make install-user
    ~/.local/bin/symlish help
'

echo -e ${GREEN}"==> Removing container image ..."${NC}
docker image rm symlish-test

echo -e ${GREEN}"==> Done!"${NC}
