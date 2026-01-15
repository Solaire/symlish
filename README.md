# � Symlish - Symbolic link manager for dotfiles

`symlish` is a Perl command-line tool that helps you manage symbolic links for your dotfiles in a clean, reversible way.

---

## Rationale

Managing my configuration began with a simple Bash script that quickly grew into a complex mess. I wanted to move away from Bash-isms and find a scripting language appropriate for system scripts, pipelines, etc. This tool started as a learning project and became a practical utility.

## How it Works

You provide Symlish with a target directory (your dotfiles root), and a command such as `link` or `unlink`. The tool will then:

1. Load and validate the `symlish.conf.yaml` configuration file
2. Expand glob patterns to find all source files and directories
3. Determine the first suitable destination path for each target group
4. Create symlinks in the destination directory for matching files/directories
5. Back up existing files (with `.bak` suffix) before linking

## Features

- **Symbolic link management** - Create and remove symlinks from a dotfiles directory
- **Platform-aware paths** - Specify multiple destination paths; Symlish uses the first one that exists
  - e.g., VS Code config path differs between Linux (`~/.config/Code/`) and Windows (`$APPDATA/Code/`)
- **Automatic backups** - Existing files are backed up (e.g., `.bashrc` → `.bashrc.bak`)
- **Backup restoration** - Backups are automatically restored when symlinks are removed
- **Dry-run mode** - Preview changes with `--dry-run` before applying them
- **Filtering** - Use `--only` or `--ignore` to process specific targets

---

## Requirements

- **Perl 5.20+** (tested with 5.36)
- **cpanm** (App::cpanminus) for dependency management

## Installation

### Quick Start

```bash
# Clone the repository
git clone https://github.com/solaire/symlish.git
cd symlish/perl

# Set up local Perl environment (if needed)
./script/install.sh

# Install dependencies
cpanm --installdeps .

# Run symlish
perl bin/Main.pl <command> <directory> [options]
```

### Global Installation

To install symlish system-wide so you can run it from anywhere:

```bash
cd symlish/perl

# Install dependencies
cpanm --installdeps .

# Install globally (may require sudo)
sudo make install
```

After installation, you can use:
```bash
symlish link ~/dotfiles --dry-run
```

### Add as a Git Submodule

From your dotfiles repository root:

```bash
# Add symlish as a submodule
git submodule add https://github.com/solaire/symlish.git symlish

# Commit your changes
git add .gitmodules symlish
git commit -m "Add symlish as a submodule"
```

Then install dependencies:
```bash
cd symlish/perl
cpanm --installdeps .
```

---

## Usage

```bash
symlish <command> <directory> [options]
```

### Examples

```bash
# Preview what symlinks would be created
symlish link ~/dotfiles --dry-run

# Create all symlinks
symlish link ~/dotfiles

# Check current symlink status
symlish status ~/dotfiles

# Remove symlinks and restore backups
symlish unlink ~/dotfiles

# Only process specific targets
symlish link ~/dotfiles --only bash,git

# Skip certain targets
symlish link ~/dotfiles --ignore vscode,emacs
```

## Commands

| Command  | Description                              |
| -------- | ---------------------------------------- |
| `link`   | Create symlinks from dotfiles to system  |
| `unlink` | Remove symlinks and restore backups      |
| `status` | Show current symlink status              |
| `help`   | Display usage information                |

## Options

| Option      | Value   | Description                                       |
| ----------- | ------- | ------------------------------------------------- |
| `--dry-run` |         | Simulate operation without making changes         |
| `--only`    | `x,y,z` | Process only the specified targets                |
| `--ignore`  | `x,y,z` | Skip the specified targets                        |

> **Note:** `--only` and `--ignore` are mutually exclusive.

---

## Configuration

Create a `symlish.conf.yaml` file in your dotfiles directory:

```yaml
link:
  # Shell configuration
  bash:
    target: bash/*           # Glob pattern for source files
    paths:                   # Destination paths (first existing is used)
      - ~/
    ignore-empty: true       # Skip empty files

  # Git configuration
  git:
    target: git/*
    paths:
      - ~/

  # VS Code (cross-platform example)
  vscode:
    target: vscode/*
    paths:
      - $APPDATA/Code/       # Windows
      - ~/.config/Code/      # Linux

  # Temporarily disabled
  emacs:
    target: emacs/.doom.d
    ignore: true             # Skip this target entirely
    paths:
      - ~/
```

### Configuration Options

| Option         | Type    | Default | Description                                    |
| -------------- | ------- | ------- | ---------------------------------------------- |
| `target`       | string  | —       | Glob pattern relative to dotfiles root         |
| `paths`        | array   | —       | List of destination paths (first valid is used)|
| `ignore`       | boolean | `false` | Skip this target entirely                      |
| `ignore-empty` | boolean | `true`  | Skip empty files and directories               |
| `conflict`     | string  | `skip`  | How to handle conflicts: `skip` or `overwrite` |

### Glob Patterns

- `bash/*` — All files in `bash/` directory (including dotfiles)
- `config/**` — All files recursively in `config/` directory
- `vim/.vimrc` — Single specific file

### Path Expansion

Paths support:
- **Environment variables:** `$HOME`, `$APPDATA`, `$XDG_CONFIG_HOME`
- **Tilde expansion:** `~/` expands to your home directory

---

## Development

### Running Tests

```bash
cd perl

# Run all tests
prove -l t/

# Run tests verbosely
prove -lv t/

# Run a specific test file
prove -lv t/00-config.t
```

### Project Structure

```
perl/
├── bin/
│   └── Main.pl          # Entry point
├── lib/
│   └── Symlish/
│       ├── Commands.pm  # link/unlink/status logic
│       ├── Config.pm    # YAML config loading
│       ├── LinkItem.pm  # Single symlink operations
│       ├── LinkTarget.pm# Target group handling
│       ├── Logger.pm    # Colored output
│       ├── Options.pm   # CLI argument parsing
│       └── Targets.pm   # Target building/filtering
├── t/                   # Test suite
│   ├── 00-config.t
│   ├── 01-options.t
│   ├── 02-link-item.t
│   ├── 03-link-target.t
│   ├── 04-targets.t
│   ├── 05-commands.t
│   ├── 06-logger.t
│   └── 07-integration.t
├── cpanfile             # Perl dependencies
└── script/
    └── install.sh       # Environment setup
```

### Dependencies

**Runtime:**
- `YAML::PP` — YAML configuration parsing

**Testing:**
- `Test::More` — Core test framework
- `Test::Exception` — Exception testing
- `Capture::Tiny` — Output capture
- `File::Temp` — Temporary files/directories

---

## License

See [LICENSE](LICENSE) for details.