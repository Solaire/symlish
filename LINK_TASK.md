# Link Operation

Add a `link` operation to allow more control over the individual configuration files/directories.

## Overview

At the moment, the config file only supports `ignore` setting which will ignore files and directories. This is not the best way to manage dotfiles; the user may only have 1 or 2 config files but will have to explicitly ignore all other files/directories. 

The flow should be inverted; the config file should only specify the configuration that needs to be managed. 

## How Would This Work?

From the context of `symlish.conf.yaml` file, the link operation is a list of files/directories which contain some arguments:
1. `paths`: List of path candidates. 
    * If the root directory of a path does not exist, it will skip that path and try the next one. If all paths are skipped, notify the user and don't do anything.
    * Generally speaking, most of dotfile configuration ends up up on the user's home directory (`~`). On Windows, MSYS2 or MinGW will create an alias the user's directory which ensures that linux paths work. Some configuration files (like vscode) are not placed in the home directory. Instead, they use different paths for different platforms:
        * Linux : `~/.config/Code`
        * Windows : `%APPDATA%/Code` -> `$APPDATA/Code` (Msys/MinGW)
2. `ignore` : Should this entry be ignored?
    * Accepted values: [true|false]
    * Default: `false`
    * Useful for temporarily disabling a configuration
    * NOTE: this will not unlink existing links
3. `ignore-empty` : Should we skip empty files and directories?
    * Accepted values: [true|false]
    * Default: `true`
4. `conflict` : How should symlink conflicts be resolved?
    * Accepted values: [skip|force]
    * Default value: `skip`
    * NOTE: Conflict resolution only applies to "foreign" symbolic links.
        * Conflicts with actual files will *always* result in creation of a `.bak` file
        * Conflicts with symbolic links that originate from the same source (i.e. have the same source as in the config file) will be ignored
## Path resolution

We can use `glob` to resolve paths so that we can specify individual files and subdirectories when creating symbolic links:
- \* : Match every file and directory in given root directory
- \*\* : Recursively match every file in given root directory

## Example config file

```bash
───────┬─────────────────────────────────────
       │ File: ../dotfiles/symlish.conf.yaml
───────┼─────────────────────────────────────
- link:
    - vscode/*: # Every file and directory in `vscode` directory
        - paths:
            - $APPDATA/Code/    # Try windows first
            - ~/.config/Code/   # Fallback to linux
    - git/**: # Every file in `git` and all subdirectories 
        - paths:
            - ~
    - emacs/.doom.d: # Just this directory
        - paths: 
            - ~
        - ignore: true
    - bash/**: # Every file in `bash` and all subdirectories 
        - paths: 
            - ~
        - ignore-empty: false # Create symlinks to empty files too (so we can update them without needing to relink)
        - conflict: overwrite
```