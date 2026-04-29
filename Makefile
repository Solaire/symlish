# Makefile for Symlish
#
# Usage:
#   make test       - Run the test suite
#   make install    - Install symlish globally (may require sudo)
#   make upgrade    - Alias for install; safe to run over an existing install
#   make uninstall  - Remove global installation
#   make clean      - Remove generated files
#
# Optional code-quality targets (require Perl::Critic / Perl::Tidy):
#   make lint       - Run Perl::Critic static analysis
#   make tidy       - Format code with Perl::Tidy
#
# For global installation you may need sudo:
#   sudo make install

SHELL := /bin/bash

# Installation paths
PREFIX      ?= /usr/local
BINDIR      := $(PREFIX)/bin
LIBDIR      := $(PREFIX)/share/perl5/symlish
EXECUTABLE  := symlish

# Source paths
SRC_BIN     := bin/Main.pl
SRC_LIB     := lib/Symlish
TEST_DIR    := t

# Perl settings
PERL        := perl
PROVE       := prove
CRITIC      := perlcritic
TIDY        := perltidy

# Colors for output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
NC     := \033[0m  # No Color

.PHONY: all test test-verbose test-file lint lint-strict tidy tidy-check \
        install upgrade uninstall install-user uninstall-user run clean help

# Default target
all: test

#=============================================================================
# Testing
#=============================================================================

## Run all tests
test:
	@echo -e "$(BLUE)==> Running tests...$(NC)"
	@$(PROVE) -l $(TEST_DIR)/
	@echo -e "$(GREEN)==> All tests passed$(NC)"

## Run tests with verbose output
test-verbose:
	@echo -e "$(BLUE)==> Running tests (verbose)...$(NC)"
	@$(PROVE) -lv $(TEST_DIR)/

## Run a specific test file (usage: make test-file FILE=t/00-config.t)
test-file:
	@$(PROVE) -lv $(FILE)

#=============================================================================
# Code Quality (optional - requires Perl::Critic / Perl::Tidy)
#=============================================================================

## Run Perl::Critic static analysis
lint:
	@echo -e "$(BLUE)==> Running Perl::Critic...$(NC)"
	@$(CRITIC) --severity 4 $(SRC_BIN) $(SRC_LIB)/*.pm || true
	@echo -e "$(GREEN)==> Lint complete$(NC)"

## Run strict lint (severity 3)
lint-strict:
	@echo -e "$(BLUE)==> Running Perl::Critic (strict)...$(NC)"
	@$(CRITIC) --severity 3 $(SRC_BIN) $(SRC_LIB)/*.pm

## Format code with Perl::Tidy
tidy:
	@echo -e "$(BLUE)==> Formatting with Perl::Tidy...$(NC)"
	@$(TIDY) -b $(SRC_BIN) $(SRC_LIB)/*.pm
	@rm -f $(SRC_BIN).bak $(SRC_LIB)/*.bak
	@echo -e "$(GREEN)==> Formatting complete$(NC)"

## Check formatting without modifying files
tidy-check:
	@echo -e "$(BLUE)==> Checking formatting...$(NC)"
	@$(TIDY) -st $(SRC_BIN) > /dev/null
	@for f in $(SRC_LIB)/*.pm; do $(TIDY) -st "$$f" > /dev/null; done
	@echo -e "$(GREEN)==> Formatting check complete$(NC)"

#=============================================================================
# Installation
#=============================================================================

## Install symlish globally (may require sudo). Safe to re-run for upgrades.
install: test
	@echo -e "$(BLUE)==> Installing symlish to $(PREFIX)...$(NC)"
	
	@# Create directories
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)
	
	@# Copy library modules
	@cp -r $(SRC_LIB) $(LIBDIR)/
	@echo -e "    Installed modules to $(LIBDIR)"
	
	@# Create executable wrapper
	@echo '#!/usr/bin/env perl' > $(BINDIR)/$(EXECUTABLE)
	@echo '' >> $(BINDIR)/$(EXECUTABLE)
	@echo 'use strict;' >> $(BINDIR)/$(EXECUTABLE)
	@echo 'use warnings;' >> $(BINDIR)/$(EXECUTABLE)
	@echo '' >> $(BINDIR)/$(EXECUTABLE)
	@echo 'use lib "$(LIBDIR)";' >> $(BINDIR)/$(EXECUTABLE)
	@echo '' >> $(BINDIR)/$(EXECUTABLE)
	@# Append the main script (skip the shebang and lib setup)
	@tail -n +9 $(SRC_BIN) >> $(BINDIR)/$(EXECUTABLE)
	
	@# Make executable
	@chmod 755 $(BINDIR)/$(EXECUTABLE)
	@echo -e "    Installed executable to $(BINDIR)/$(EXECUTABLE)"
	
	@echo -e "$(GREEN)==> Installation complete!$(NC)"
	@echo -e "    Run 'symlish help' to get started"

## Upgrade an existing installation (alias for install)
upgrade: install

## Remove global installation
uninstall:
	@echo -e "$(BLUE)==> Uninstalling symlish...$(NC)"
	@rm -f $(BINDIR)/$(EXECUTABLE)
	@rm -rf $(LIBDIR)
	@echo -e "$(GREEN)==> Uninstallation complete$(NC)"

## Install to user's local bin (no sudo required)
install-user: test
	@$(MAKE) install PREFIX=$(HOME)/.local

## Uninstall from user's local bin
uninstall-user:
	@$(MAKE) uninstall PREFIX=$(HOME)/.local

#=============================================================================
# Development
#=============================================================================

## Run the application locally (usage: make run ARGS="link ~/dotfiles --dry-run")
run:
	@$(PERL) -Ilib $(SRC_BIN) $(ARGS)

## Clean generated files
clean:
	@echo -e "$(BLUE)==> Cleaning...$(NC)"
	@rm -f $(SRC_LIB)/*.bak
	@rm -f $(SRC_BIN).bak
	@rm -rf cover_db/
	@echo -e "$(GREEN)==> Clean complete$(NC)"

#=============================================================================
# Help
#=============================================================================

## Show this help message
help:
	@echo ""
	@echo "Symlish Makefile"
	@echo "================"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  test          Run the test suite"
	@echo "  test-verbose  Run tests with verbose output"
	@echo "  test-file     Run specific test (FILE=t/00-config.t)"
	@echo ""
	@echo "  lint          Run Perl::Critic (severity 4)  [requires Perl::Critic]"
	@echo "  lint-strict   Run Perl::Critic (severity 3)  [requires Perl::Critic]"
	@echo "  tidy          Format code with Perl::Tidy    [requires Perl::Tidy]"
	@echo "  tidy-check    Check formatting without changes"
	@echo ""
	@echo "  install       Install globally to $(PREFIX) (may need sudo)"
	@echo "  upgrade       Upgrade an existing installation (alias for install)"
	@echo "  uninstall     Remove global installation"
	@echo "  install-user  Install to ~/.local (no sudo)"
	@echo "  uninstall-user Remove user installation"
	@echo ""
	@echo "  run           Run locally (ARGS=\"link ~/dotfiles\")"
	@echo "  clean         Remove generated files"
	@echo "  help          Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make test                          # Run all tests"
	@echo "  make run ARGS=\"status ~/dotfiles\" # Test locally"
	@echo "  sudo make install                  # Install globally"
	@echo "  sudo make upgrade                  # Upgrade existing install"
	@echo "  make install-user                  # Install to ~/.local"
	@echo ""
