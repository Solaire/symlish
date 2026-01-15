# cpanfile - Perl dependencies for Symlish
# Install with: cpanm --installdeps .

# Runtime dependencies
requires 'YAML::PP', '>= 0.035';   # YAML parsing for config files

# Core modules (included with Perl, listed for documentation)
requires 'Getopt::Long';           # CLI option parsing
requires 'File::Spec';             # Portable file path operations
requires 'File::Basename';         # Extract filename from path
requires 'File::Glob';             # Shell-style glob expansion
requires 'Cwd';                    # Get current working directory
requires 'FindBin';                # Locate script directory
requires 'Exporter';               # Module export functionality

# Development/testing dependencies
on 'test' => sub {
    requires 'Test::More';         # Core testing framework
    requires 'Test::Exception';    # Test code that throws exceptions
    requires 'File::Temp';         # Create temporary files/directories
    requires 'File::Path';         # Create/remove directory trees
    requires 'Capture::Tiny';      # Capture stdout/stderr in tests
};

# Development tools (optional)
on 'develop' => sub {
    requires 'Perl::Critic';       # Static code analysis / linting
    requires 'Perl::Tidy';         # Code formatter
};
