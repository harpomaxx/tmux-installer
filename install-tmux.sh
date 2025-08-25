#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Fancy tmux setup via AppImage (latest)
# ==========================================
# - Fetches the latest AppImage from nelsonenzo/tmux-appimage
# - Installs to ~/.local/bin/tmux (idempotent)
# - Installs TPM + writes ~/.tmux.conf (compat-safe)
# - Installs clipboard helpers where possible
# - Manual plugin install (user runs Prefix + I)
#
# Usage:
#   chmod +x install-tmux.sh
#   ./install-tmux.sh
#
# Optional env:
#   TMUX_FORCE_APPIMAGE=1     # force re-download even if present
#   TMUX_ARCH=auto|x86_64|aarch64   # override arch detection
#   TMUX_NO_CLIP_HELPERS=1    # skip installing wl-clipboard/xclip
# ==========================================

msg() { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! \033[0m%s\n" "$*"; }
err() { printf "\033[1;31m!! \033[0m%s\n" "$*" >&2; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
ARCH_RAW="${TMUX_ARCH:-auto}"
if [[ "$ARCH_RAW" == "auto" ]]; then
  case "$(uname -m)" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) ARCH="x86_64"; warn "Unknown arch $(uname -m); defaulting to x86_64." ;;
  esac
else
  ARCH="$ARCH_RAW"
fi

# Detect package manager (best-effort, for helpers only)
PKG=""
if [[ "$OS" != "Darwin" ]]; then
  for p in apt dnf yum pacman zypper; do
    if need_cmd "$p"; then PKG="$p"; break; fi
  done
fi

install_pkgs() {
  # $@ packages
  case "$PKG" in
    apt) sudo apt-get update -y && sudo apt-get install -y "$@" ;;
    dnf) sudo dnf install -y "$@" ;;
    yum) sudo yum install -y "$@" ;;
    pacman) sudo pacman -Sy --noconfirm "$@" ;;
    zypper) sudo zypper install -y "$@" ;;
    *) warn "No supported package manager found. Skipping install of: $*"; return 1 ;;
  esac
}

ensure_cmd() {
  local bin="$1"
  local pkg_hint="${2:-}"
  if ! need_cmd "$bin"; then
    if [[ -n "$pkg_hint" ]]; then
      msg "Installing $bin..."
      install_pkgs "$pkg_hint" || warn "Could not install $bin automatically."
    else
      warn "$bin not found; please install it."
    fi
  fi
}

# --- prerequisites ---
if [[ "$OS" == "Darwin" ]]; then
  ensure_cmd curl ""
  ensure_cmd git ""
else
  ensure_cmd curl curl
  ensure_cmd git git
fi

# --- ensure ~/.local/bin on PATH ---
mkdir -p "$HOME/.local/bin"

# Always ensure ~/.local/bin is in current session's PATH
if ! printf "%s" "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
  export PATH="$HOME/.local/bin:$PATH"
  msg "Added ~/.local/bin to current session PATH"
fi

# Also add to shell rc for future sessions (if not already there)
if ! grep -q 'export PATH=.*\.local/bin' "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.${SHELL##*/}rc" 2>/dev/null; then
  SHELL_NAME="$(basename "${SHELL:-bash}")"
  RC_FILE="$HOME/.${SHELL_NAME}rc"
  if [[ ! -f "$RC_FILE" ]]; then
    # fallback to common ones
    for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
      [[ -f "$f" ]] && RC_FILE="$f" && break
    done
  fi
  {
    echo ''
    echo '# Added by install-tmux.sh'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$RC_FILE"
  msg "PATH updated in $(basename "$RC_FILE") for future sessions."
fi

# --- install tmux AppImage (latest) ---
APPIMAGE_PATH="$HOME/.local/bin/tmux.AppImage"
TMUX_SHIM="$HOME/.local/bin/tmux"

download_latest_appimage() {
  local api="https://api.github.com/repos/nelsonenzo/tmux-appimage/releases/latest"
  local url

  msg "Fetching latest Tmux AppImage release (arch=$ARCH)..."
  # Parse without jq:
  url="$(curl -fsSL "$api" \
      | grep -oE '"browser_download_url":\s*"[^"]+"' \
      | cut -d'"' -f4 \
      | grep -i "AppImage" \
      | head -n1 || true)"

  if [[ -z "$url" ]]; then
    err "Could not find a matching AppImage for arch=$ARCH from $api"
    return 1
  fi

  msg "Downloading: $url"
  curl -fLo "$APPIMAGE_PATH" "$url"
  chmod +x "$APPIMAGE_PATH"
}

ensure_tmux_appimage() {
  local need_download=0
  if [[ ! -f "$APPIMAGE_PATH" ]]; then
    need_download=1
  elif [[ "${TMUX_FORCE_APPIMAGE:-0}" = "1" ]]; then
    need_download=1
  fi
  if [[ "$need_download" -eq 1 ]]; then
    download_latest_appimage || return 1
  else
    msg "Tmux AppImage already present. Skipping download."
  fi

  # Create/refresh shim that runs the AppImage with fallback.
  cat > "$TMUX_SHIM" <<'SHIM'
#!/usr/bin/env bash
APP="$HOME/.local/bin/tmux.AppImage"

# Function to test if AppImage works
test_appimage() {
    timeout 3 "$APP" -V >/dev/null 2>&1
}

# Try normal AppImage first
if test_appimage; then
    exec "$APP" "$@"
else
    # Fallback to extract-and-run method for FUSE issues
    export APPIMAGE_EXTRACT_AND_RUN=1
    if timeout 3 "$APP" -V >/dev/null 2>&1; then
        exec "$APP" "$@"
    else
        # Final fallback to system tmux if available
        if command -v /usr/bin/tmux >/dev/null 2>&1; then
            echo "Warning: AppImage failed, using system tmux" >&2
            exec /usr/bin/tmux "$@"
        else
            echo "Error: tmux AppImage failed and no system tmux found" >&2
            echo "Try: APPIMAGE_EXTRACT_AND_RUN=1 ~/.local/bin/tmux.AppImage" >&2
            exit 1
        fi
    fi
fi
SHIM
  chmod +x "$TMUX_SHIM"

  # Show version
  if "$TMUX_SHIM" -V >/dev/null 2>&1; then
    msg "Installed $( "$TMUX_SHIM" -V ) via AppImage."
  else
    warn "Tmux shim runs but did not report a version. You can still try: $TMUX_SHIM -V"
  fi
}

msg "Installing Tmux via AppImage..."
ensure_tmux_appimage || {
  warn "Falling back: system tmux (if available) will be used."
}

# --- clipboard helpers (Linux only, best-effort) ---
if [[ "$OS" != "Darwin" && "${TMUX_NO_CLIP_HELPERS:-0}" != "1" ]]; then
  want=()
  need_cmd wl-copy || want+=("wl-clipboard")
  need_cmd xclip   || want+=("xclip")
  if ((${#want[@]})); then
    msg "Installing clipboard helpers: ${want[*]}"
    install_pkgs "${want[@]}" || warn "Could not install clipboard helpers; system clipboard yanks may be limited."
  fi
else
  msg "Skipping clipboard helpers on macOS or by request."
fi

# --- TPM (tmux plugin manager) ---
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
  msg "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  msg "Updating TPM..."
  git -C "$TPM_DIR" pull --ff-only || true
fi

# --- write ~/.tmux.conf (idempotent; backup existing) ---
TMUX_CONF="$HOME/.tmux.conf"
if [[ -f "$TMUX_CONF" ]]; then
  cp "$TMUX_CONF" "$TMUX_CONF.bak.$(date +%s)"
  msg "Backed up existing ~/.tmux.conf"
fi

msg "Writing ~/.tmux.conf"
cat > "$TMUX_CONF" <<'TMUXCONF'
##### Basics
set -g default-terminal "screen-256color"
set -g history-limit 100000
set -g mouse on
set -g renumber-windows on
set -g base-index 1
setw -g pane-base-index 1
setw -g aggressive-resize on
set -g escape-time 10

# Enhanced terminal support (only if terminal supports it)
if-shell 'infocmp tmux-256color >/dev/null 2>&1' \
  'set -g default-terminal "tmux-256color"'
if-shell '[[ "$TERM" =~ "256color" ]]' \
  'set -as terminal-features "xterm-256color:RGB"; set -ga terminal-overrides ",xterm-256color:Tc"'

##### Prefix & QoL
unbind C-b
set -g prefix C-a
bind C-a send-prefix
bind r source-file ~/.tmux.conf \; display-message "tmux reloaded ✔"
bind | split-window -h
bind - split-window -v
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5
bind x confirm-before -p "kill-pane? (y/n)" kill-pane

##### Copy mode (vim-style) + clipboard fallback
setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
if-shell 'command -v pbcopy >/dev/null' \
  "unbind -T copy-mode-vi y; bind -T copy-mode-vi y send -X copy-pipe-and-cancel 'pbcopy'"
if-shell 'command -v xclip >/dev/null' \
  "unbind -T copy-mode-vi y; bind -T copy-mode-vi y send -X copy-pipe-and-cancel 'xclip -selection clipboard -in'"
if-shell 'command -v wl-copy >/dev/null' \
  "unbind -T copy-mode-vi y; bind -T copy-mode-vi y send -X copy-pipe-and-cancel 'wl-copy'"

##### Status line (clean + informative)
set -g status-interval 5
set -g status-position bottom
set -g status-justify centre
set -g status-left-length 40
set -g status-right-length 120
set -g status-left  "#S "
set -g status-right "#(whoami) • #{hostname} • %Y-%m-%d %H:%M"

##### Popup binding (only if tmux >= 3.2)
if-shell '[ "$(tmux -V | cut -d" " -f2 | tr -d "[:alpha:]")" \> "3.1" ]' \
  'bind -n F2 display-popup -E -w 80% -h 80% -T "Quick Shell"'

##### Plugins (TPM) - Only load if TPM exists and plugins are installed
if-shell '[ -f ~/.tmux/plugins/tpm/tpm ]' {
  set -g @plugin 'tmux-plugins/tpm'
  set -g @plugin 'tmux-plugins/tmux-sensible'
  set -g @plugin 'tmux-plugins/tmux-yank'
  set -g @plugin 'tmux-plugins/tmux-resurrect'
  set -g @plugin 'tmux-plugins/tmux-continuum'
  set -g @plugin 'catppuccin/tmux'

  # Catppuccin theme tweaks
  set -g @catppuccin_flavour 'mocha'
  set -g @catppuccin_window_status_style 'rounded'
  set -g @catppuccin_date_time "%H:%M"
  set -g @catppuccin_left_separator  ""
  set -g @catppuccin_right_separator ""

  # Continuum/Resurrect - disable auto-restore initially
  set -g @continuum-restore 'off'
  set -g @resurrect-capture-pane-contents 'on'

  # Load TPM (keep this at the very bottom)
  run '~/.tmux/plugins/tpm/tpm'
}
TMUXCONF

# --- optional terminfo (best-effort) ---
if ! infocmp tmux-256color >/dev/null 2>&1; then
  msg "tmux-256color terminfo not found, attempting local install..."
  if infocmp xterm-256color >/dev/null 2>&1; then
    infocmp xterm-256color | sed 's/xterm/tmux/' > /tmp/tmux-256color.src || true
    tic -x -o "${HOME}/.terminfo" /tmp/tmux-256color.src || true
  else
    warn "Could not generate tmux-256color from xterm-256color; continuing."
  fi
fi

# --- plugin installation note ---
msg "Done! Tmux is ready with a safe configuration that won't hang."
echo
echo "🎯 Quick Start:"
echo "  • Start tmux: tmux"
echo "  • Try splits: Ctrl-a |   and   Ctrl-a -"
echo "  • Navigate panes: Ctrl-a h/j/k/l"
echo "  • Reload config: Ctrl-a then r"
echo
echo "🎨 Optional - Install plugins for themes & extra features:"
echo "  1. Start tmux: tmux"
echo "  2. Install plugins: Ctrl-a + I (capital I)"
echo "  3. Enable auto-restore: Edit ~/.tmux.conf and change @continuum-restore to 'on'"
echo
echo "📋 Features included:"
echo "  • Copy: Ctrl-a [  then v ... y  (uses system clipboard)"
echo "  • Popup (tmux ≥ 3.2): F2"
echo "  • Mouse support: enabled"
echo "  • Vim-style navigation: enabled"
echo
echo "⚠️ Troubleshooting:"
echo "  • If tmux hangs, try: tmux -f /dev/null (starts with no config)"
echo "  • FUSE error: APPIMAGE_EXTRACT_AND_RUN=1 tmux"