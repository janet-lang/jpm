# Shell completions for jpm and janet

This directory contains shell completion scripts for `jpm` and `janet`.

## jpm

### Bash

```bash
# User install (no root required)
cp jpm.bash ~/.local/share/bash-completion/completions/jpm
# or source directly from ~/.bashrc:
source /path/to/jpm.bash
```

### Fish

```fish
cp jpm.fish ~/.config/fish/completions/jpm.fish
```

### Zsh

```zsh
# Place in a directory on your $fpath
cp jpm.zsh ~/.zsh/completions/_jpm
# Ensure ~/.zsh/completions is in $fpath in ~/.zshrc:
# fpath=(~/.zsh/completions $fpath)
# autoload -Uz compinit && compinit
```

## janet

### Bash

```bash
cp janet.bash ~/.local/share/bash-completion/completions/janet
```

### Fish

```fish
cp janet.fish ~/.config/fish/completions/janet.fish
```

### Zsh

```zsh
cp janet.zsh ~/.zsh/completions/_janet
```
