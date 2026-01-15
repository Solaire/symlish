#!/usr/bin/env bash
#
# install.sh - Set up Perl environment for Symlish
#
# This script installs cpanminus and local::lib for non-root Perl module
# installation. Run this once on a fresh system before installing dependencies.
#
# Usage:
#   ./script/install.sh        # Set up local Perl environment
#   cpanm --installdeps .      # Install dependencies from cpanfile
#
# Source: https://stackoverflow.com/questions/2980297
# License: CC BY-SA 4.0

set -e

echo "==> Setting up local Perl environment..."

# Install cpanminus and local::lib to ~/perl5
if command -v cpanm &> /dev/null; then
    echo "    cpanm already installed, skipping..."
else
    echo "    Installing cpanminus and local::lib..."
    wget -q -O- http://cpanmin.us | perl - -l ~/perl5 App::cpanminus local::lib
fi

# Configure shell to use local::lib
SHELL_RC=""
if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

# Add local::lib configuration if not already present
LOCAL_LIB_EVAL='eval $(perl -I ~/perl5/lib/perl5 -Mlocal::lib)'

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q "local::lib" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Perl local::lib configuration (added by symlish)" >> "$SHELL_RC"
        echo "$LOCAL_LIB_EVAL" >> "$SHELL_RC"
        echo 'export MANPATH=$HOME/perl5/man:$MANPATH' >> "$SHELL_RC"
        echo "    Added local::lib config to $SHELL_RC"
    else
        echo "    local::lib already configured in $SHELL_RC"
    fi
fi

# Activate local::lib for current session
eval $(perl -I ~/perl5/lib/perl5 -Mlocal::lib)

echo ""
echo "==> Done! Next steps:"
echo "    1. Restart your shell or run: source $SHELL_RC"
echo "    2. Install dependencies: cpanm --installdeps ."
echo ""
