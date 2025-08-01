# 💎 Symlish - Symbolic link manager for dotfiles

![](image.png) `symlish` is a Ruby-based command-line tool that helps you manage symbolic links for your dotfiles in a clean, reversible way.

> NOTE
>
> Currently work in progress, and not all features might work as expected.

---

## Rationale

Managing my configuration began with a simple Bash script that quickly grew into a complex mess. I wanted to move away from Bash-isms and find a scripting language appropriate for system scripts, pipelines, etc. Ruby worked well and so Symlish was born; a tool that started as a learning project and became a practical utility.

## How it Works

You provide Symlish with a target directory (your dotfiles root), and a command such as link or unlink. The tool with then:
1. Extract the targets from the `symlish.conf.yaml` configuration file.
2. Expand the target filepaths to find all target files and directories.
3. Determine the first suitable destination path for each target group.
4. Creates symlinks in the destination directory for matching files/directories.
5. Backs up existing files (with `.bak` suffix) before linking.

## Features

- Create symbolic links from a dotfiles directory to a target directory.
- Determines the best destination path for the config:
   - e.g. vscode config path is platform-specific. You can provide paths to each platform and symlish will apply the correct one.
- Automatically backs up existing files (e.g., `.bashrc` ~> `.bashrc.bak`).
- Restores backups when symlinks are removed.
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

## Add it to your dotfiles repo as a submodule

From your dotfiles repository root:
```bash
git submodule add https://github.com/solaire/symlish.git symlish

# Commit your changes:
git add .gitmodules symlish
git commit -m "Add symlish as a submodule"
git push
```

You can them build it:
```bash
cd symlish
gem build symlish.gemspec 
sudo gem install symlish-*.gem
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

## Options

| Option      | Value | Description                                          |
| ----------- | ----- | ---------------------------------------------------- |
| `--dry-run` |       | Simulate operation without making changes            |
| `--include` | x,y,z | Only include specified items                         |
| `--only`    | x,y,z | Include only listed items (overrides include/ignore) |

> NOTE
>
> The `--only` option will overwrite content of `symlish.conf.yaml`.

## Configuration

Add a `symlish.conf.yaml` file to your dotfiles directory:
```yaml
link:
  vscode:
    target: vscode/*
    paths:
      - $APPDATA/Code/
      - ~/.config/Code/
  git:
    target: git/**
    paths:
      - ~/
  emacs:
    target: emacs/.doom.d
    ignore: true
    paths:
      - ~/
  bash:
    target: bash/**
    paths:
      - ~/
    ignore-empty: true

```