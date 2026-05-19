# Symlish - Symbolic link manager for dotfiles

![](image.png)  

`symlish` is a Perl command-line tool for managing symbolic links. Primarily designed for dotfiles management.

## Rationale

this tool exists partly because I wanted a configurable way of managing my dotfiles using symbolic links, and partly to explore Perl's capabilities as a system scripting language.

## How it Works

Symlish is a config-driven tool. The two main commands are `apply` (create the symlinks) and `clean` (remove them and restore any backups). Invoke the tool with a command and a path to the directory holding your config, and it will:

1. Load and validate the `symlish.conf.ini` configuration file
2. Expand glob patterns to find all source files and directories
3. Determine the first suitable destination path for each target group
5. Back up any existing files at the destination (with a `.bak` suffix)
4. Create symlinks in the destination directory for matching files 

## Features

- Config-driven
    - Uses an INI config file to define the symbolic link targets and paths
    - A single config file can hold multiple profiles, each managed independently (e.g. work and personal)
- Platform-aware paths
    - Specify multiple destination paths; first valid one will be used
    - e.g. VS Code config path differs between Linux (`~/.config/Code/`) and Windows (`$APPDATA/Code/`)
- Automatic backups
    - Existing files are backed up (e.g., `.bashrc` -> `.bashrc.bak`)
    - Backups are automatically restored when symlinks are removed
- CLI options
    - `--dry-run` will preview changes without applying them
    - use `--only` or `--ignore` to process specific targets
- No dependencies; uses only Perl core modules

---

## Requirements

- Perl 5.20+ (tested with 5.36)

## Installation

### Quick Start

```bash
# Clone the repository
git clone https://github.com/solaire/symlish.git
cd symlish

# Run directly
perl bin/Main.pl <command> <directory> [options]
```

### Global Installation

```bash
# Install globally (may require sudo)
sudo make install

# Alternatively, install to user's local bin (no sudo required)
make install-user
```

After installation, you can use:
```bash
symlish apply ~/dotfiles --dry-run
```

### Upgrading

Re-running `make install` (or `make install-user`) safely overwrites an existing installation.

### Add as a Git Submodule

From your dotfiles repository root:

```bash
git submodule add https://github.com/solaire/symlish.git symlish
git add .gitmodules symlish
git commit -m "Add symlish as a submodule"
```

Then run directly or install:
```bash
cd symlish
make install-user
```

---

## Usage

```bash
symlish <command> <directory> [options]
```

### Examples

```bash
# Preview what symlinks would be created
symlish apply ~/dotfiles --dry-run

# Create all symlinks
symlish apply ~/dotfiles

# Check current symlink status
symlish status ~/dotfiles

# Remove symlinks and restore backups
symlish clean ~/dotfiles

# Only process specific targets
symlish apply ~/dotfiles --only bash,git

# Skip certain targets
symlish apply ~/dotfiles --ignore vscode,emacs

# Specify profile
symlish apply ~/dotfiles --profile editors
```

## Commands

| Command   | Description                              |
| --------- | ---------------------------------------- |
| `apply`   | Create symlinks from dotfiles to system  |
| `clean`   | Remove symlinks and restore backups      |
| `status`  | Show current symlink status              |
| `help`    | Display usage information                |
| `version` | Display version                          |

## Options

| Option      | Value   | Description                                       |
| ----------- | ------- | ------------------------------------------------- |
| `--dry-run` |         | Simulate operation without making changes         |
| `--only`    | `x,y,z` | Process only the specified targets                |
| `--ignore`  | `x,y,z` | Skip the specified targets                        |
| `--verbose` |         | Enable verbose logging to STDOUT                  |
| `--profile` | `value` | Specifies the profile that will be applied        |

> Note: `--only` and `--ignore` are mutually exclusive.

---

## Configuration

### Configuration Options

| Option         | Type    | Default | Description                                                                                                                      |
| -------------- | ------- | ------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `target`       | string  | —       | Glob pattern. Relative paths resolve against the directory of the config file; absolute paths are also accepted (reverse config) |
| `paths`        | list    | —       | Comma-separated destination paths. The first one that exists is used; can be absolute or relative.                               |
| `ignore`       | boolean | `false` | Skip this target entirely                                                                                                        |
| `ignore-empty` | boolean | `true`  | Skip empty files and directories                                                                                                 |
| `conflict`     | string  | `skip`  | How to handle conflicts: `skip` or `overwrite`                                                                                   |

### Glob Patterns

- `bash/*`      — All files in `bash/` directory (including dotfiles)
- `git/*.conf`  — All `.conf` files in `git/` directory
- `vim/.vimrc`  — Single specific file

> Note: `**` is not expanded as a recursive globstar; only `*` (one path component) is supported.

### Path Expansion

Paths support:
- Environment variables: `$HOME`, `$APPDATA`, `$XDG_CONFIG_HOME`
- Tilde expansion: `~/` expands to your home directory

> Note: Windows-style paths, e.g. %APPDATA%, are not supported. Symlish is designed mainly for Unix, or MinGW/MSYS2 environments.

### Profiles

Starting in `1.1.0`, a single `symlish.conf.ini` can hold multiple profiles; useful for keeping related-but-distinct setups in one file (Windows vs. Linux, work vs. personal, etc.).

Profiles are declared with `[[profile]]` headers and are optional. A config with no `[[profile]]` headers gets an implicit `default` profile, so legacy configs keep working untouched.

When the config has multiple profiles, pick one with `--profile <name>`. If there's only one profile (explicit or implicit `default`), `--profile` is ignored and the sole profile is selected automatically.

### Reverse config

Also starting in `1.1.0`, symlish supports the idea of "reverse configuration".

Initially this tool was designed mainly for dotfile-like projects; all config files exist in a single directory, and are symlinked to various directories in the system. Reverse configuration allows the user to specify files/directories across the machine, using absolute paths, and symlish will "pull" them to a single location. For example:

- Forward config
    - All config files live in `~/git/dotfiles`
    - Symlish links them out to various locations on the machine (e.g. `~/.config/`, `~/`)
- Reverse config
    - Config files live in various locations (e.g. `~/.config/code/`, `~/.bashrc`)
    - Symlish links them into a single location (e.g. `~/git/dotfiles`)

> NOTE: It's worth mentioning that absolute target paths will be flattened. For example: `/etc/myapp/sub/foo.conf` will resolve to `<dest>/foo.conf` instead of `<dest>/sub/foo.conf`. With absolute paths, it's currently not possible to specify an anchor directory.

### Example

Create a `symlish.conf.ini` file in your dotfiles directory.

```ini
[[main]]

; Shell configuration
[bash]
target = bash/*
paths = ~/
ignore-empty = true

; Git configuration
[git]
target = git/*
paths = ~/

; VS Code (cross-platform: first existing path is used)
[vscode]
target = vscode/*
paths = $APPDATA/Code/, ~/.config/Code/

; Temporarily disabled
[emacs]
target = emacs/.doom.d
ignore = true
paths = ~/
```

`[[profile]]` headers group related entries; each `[entry]` defines a target group that expands via glob into one or more symlinks.

---

## Development

### Running Tests

```bash
# Run all tests
make test

# Run tests verbosely
make test-verbose

# Run a specific test file
make test-file FILE=t/00-config.t

```

## License

See [LICENSE](LICENSE) for details.
