# Tmux AppImage Installer

A comprehensive script for installing tmux via AppImage with a complete, production-ready configuration.

## Features

- **Latest Tmux**: Downloads the latest tmux AppImage from [nelsonenzo/tmux-appimage](https://github.com/nelsonenzo/tmux-appimage)
- **Cross-platform**: Supports Linux (x86_64, aarch64) and macOS
- **Idempotent**: Safe to run multiple times
- **Full Configuration**: Includes a complete `.tmux.conf` with sensible defaults
- **Plugin Management**: Pre-configured with TPM (Tmux Plugin Manager) and popular plugins
- **Clipboard Integration**: Automatic clipboard helper installation (wl-clipboard, xclip)
- **Smart PATH Management**: Automatically adds `~/.local/bin` to PATH

## Quick Start

```bash
chmod +x install-tmux.sh
./install-tmux.sh
```

## What It Does

1. **Downloads tmux AppImage**: Fetches the latest release and installs to `~/.local/bin/tmux`
2. **Installs TPM**: Downloads and configures the Tmux Plugin Manager
3. **Creates Configuration**: Writes a comprehensive `~/.tmux.conf` with:
   - Vim-style key bindings
   - Mouse support
   - System clipboard integration
   - Catppuccin theme
   - Sensible defaults for splits, panes, and navigation
4. **Installs Clipboard Helpers**: Installs `wl-clipboard` and `xclip` for seamless copy/paste
5. **Sets Up PATH**: Ensures `~/.local/bin` is in your shell's PATH

## Configuration

The script creates a full-featured tmux configuration with:

- **Prefix Key**: `Ctrl-a` (instead of default `Ctrl-b`)
- **Splits**: `Prefix + |` (vertical), `Prefix + -` (horizontal)
- **Pane Navigation**: `Prefix + h/j/k/l` (vim-style)
- **Pane Resizing**: `Prefix + H/J/K/L` (hold for repeat)
- **Copy Mode**: `Prefix + [`, then `v` to select, `y` to copy
- **Reload Config**: `Prefix + r`
- **Popup Window**: `F2` (tmux ≥ 3.2)

## Pre-configured Plugins

- **tmux-sensible**: Sensible defaults for tmux
- **tmux-yank**: Enhanced clipboard integration
- **tmux-resurrect**: Save and restore tmux sessions
- **tmux-continuum**: Automatic session saving
- **catppuccin/tmux**: Beautiful Catppuccin theme

After installation, press `Prefix + I` (Ctrl-a + I) to install plugins.

## Environment Variables

- `TMUX_FORCE_APPIMAGE=1`: Force re-download even if AppImage exists
- `TMUX_ARCH=auto|x86_64|aarch64`: Override architecture detection
- `TMUX_NO_CLIP_HELPERS=1`: Skip installing clipboard helpers

## System Requirements

- **Linux**: Any distribution with a modern package manager
- **macOS**: Homebrew recommended for dependencies
- **Dependencies**: curl, git (automatically installed on Linux)

## Troubleshooting

### FUSE Error
If you encounter a FUSE error when launching tmux:
```bash
APPIMAGE_EXTRACT_AND_RUN=1 tmux
```

### Plugin Installation
If plugins don't install automatically:
1. Start tmux: `tmux`
2. Press `Prefix + I` (Ctrl-a + I)
3. Wait for installation to complete

### Clipboard Issues
Ensure you have the appropriate clipboard tool:
- **Wayland**: `wl-clipboard`
- **X11**: `xclip`
- **macOS**: `pbcopy` (built-in)

## License

MIT License - feel free to use and modify as needed.

## Contributing

Contributions welcome! Please open an issue or pull request.