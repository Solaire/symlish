# 💎 Symlish - Symbolic link manager for dotfiles

![](symlish.png) `symlish` is a Ruby-based command-line tool that helps you manage symbolic links for your dotfiles in a clean, reversible way.

> NOTE
>
> Currently work in progress, and not all features might work as expected.

---

## Rationale

Managing my configuration began with a simple Bash script that quickly grew into a complex mess. I wanted to move away from Bash-isms and find a scripting language appropriate for system scripts, pipelines, etc. Ruby worked well and so Symlish was born; a tool that started as a learning project and became a practical utility.

## How it Works

You provide Symlish with a target directory (your dotfiles root), and a command such as link or unlink. The tool then:
1. Scans top-level directories (e.g. `bash/`, `git/`, `vscode/`).
2. For each directory, it looks for:
   * config files (e.g. `.bashrc`)
   * config directories (e.g. `.doom.d`)
3. Creates symlinks in the home directory for matching files/directories.
4. Backs up existing files (with `.bak` suffix) before linking.
5. Ignores:
   * Items listed in `symlish.conf.yaml`
   * Top-level files (like `README.md`)
   * Empty file/directories.
   * Non-configuration files/directories.

## Features

- Create symbolic links from a dotfiles directory to your home directory.
- Automatically backs up existing files (e.g., `.bashrc` ~> `.bashrc.bak`).
- Restores backups when symlinks are removed.
- Supports ignore/include filters via a YAML config or command-flag options.
- Supports `--dry-run` mode for safe preview.

---

## Installation

Install via RubyGems (after building locally or publishing):

```bash
gem install symlish
```

Or clone the repo and run directly:
```bash
git clone https://github.com/yourusername/symlish.git
cd symlish
bundle install
bin/symlish <target-directory> <command> [options]
```

# Usage

```bash
symlish <target-directory> <command> [options]
```

### Example

Show what symlinks would be created, without making changes:
```bash
symlish ~/dotfiles link --dry-run
```

## Commands

| Command  | Description                         |
| -------- | ----------------------------------- |
| `link`   | Create symlinks                     |
| `unlink` | Remove symlinks and restore backups |
| `status` | Show current link status            |
| `help`   | Show usage help                     |

## Options

| Option      | Value | Description                                          |
| ----------- | ----- | ---------------------------------------------------- |
| `--dry-run` |       | Simulate operation without making changes`           |
| `--include` | x,y,z | Only include specified items                         |
| `--ignore`  | x,y,z | Exclude specified items                              |
| `--only`    | x,y,z | Include only listed items (overrides include/ignore) |

> NOTE
>
> The `--only` option will overwrite content of `symlish.conf.yaml`.

## Configuration

Add a `symlish.conf.yaml` file to your dotfiles directory to ignore specific items globally:
```yaml
ignore:
  - .git
  - fonts
  - scripts
```