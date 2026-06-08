#!/usr/bin/env bash
#
# install.sh — deploy this rice onto a fresh macOS machine.
#
#   Components:
#     sketchybar/.config/sketchybar      -> ~/.config/sketchybar
#     kitty/.config/kitty                -> ~/.config/kitty
#     tmux.conf                          -> ~/.tmux.conf
#     ohmyzsh/custom/themes/*.zsh-theme  -> $ZSH_CUSTOM/themes (oh-my-zsh)
#     spicetify/                         -> ~/.config/spicetify
#     fonts/*.ttf                       -> ~/Library/Fonts
#     wallpapers/current-wallpaper.*     -> ~/Pictures/taro-rice/
#
#   Usage:
#     ./install.sh             # back up existing files, then install
#     ./install.sh --no-backup # overwrite without backups
#     ./install.sh --deps-only # only run `brew bundle` (dependencies)
#     ./install.sh --link      # symlink configs instead of copying
#
set -euo pipefail

# --- resolve paths ----------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.rice-backup/$TS"

DO_BACKUP=1
DEPS_ONLY=0
USE_LINK=0
for arg in "$@"; do
	case "$arg" in
	--no-backup) DO_BACKUP=0 ;;
	--deps-only) DEPS_ONLY=1 ;;
	--link) USE_LINK=1 ;;
	-h | --help)
		sed -n '2,16p' "$0"
		exit 0
		;;
	*)
		echo "Unknown option: $arg" >&2
		exit 1
		;;
	esac
done

info() { printf '\033[1;35m::\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }

# Back up a destination path (file or dir) before it is overwritten.
backup() {
	local dest="$1"
	[ "$DO_BACKUP" -eq 1 ] || return 0
	if [ -e "$dest" ] || [ -L "$dest" ]; then
		mkdir -p "$BACKUP_DIR"
		local rel="${dest#"$HOME"/}"
		local target="$BACKUP_DIR/$rel"
		mkdir -p "$(dirname "$target")"
		cp -R "$dest" "$target"
		warn "backed up $dest -> $target"
	fi
}

# Deploy src -> dest, either by copy (default) or symlink (--link).
deploy() {
	local src="$1" dest="$2"
	backup "$dest"
	mkdir -p "$(dirname "$dest")"
	if [ "$USE_LINK" -eq 1 ]; then
		rm -rf "$dest"
		ln -snf "$src" "$dest"
		info "linked $dest -> $src"
	else
		rm -rf "$dest"
		cp -R "$src" "$dest"
		info "copied $src -> $dest"
	fi
}

# Merge a directory into an existing destination after backing up the destination.
# This is used for app-managed folders where symlinking is brittle.
merge_dir() {
	local src="$1" dest="$2"
	[ -d "$src" ] || return 0
	backup "$dest"
	mkdir -p "$dest"
	cp -R "$src/." "$dest/"
	info "merged $src -> $dest"
}

set_spicetify_config() {
	local key="$1" value="$2" tmp
	tmp="$(mktemp)"
	awk -v key="$key" -v value="$value" '
		BEGIN { done = 0 }
		$0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
			printf "%-22s = %s\n", key, value
			done = 1
			next
		}
		{ print }
		END {
			if (!done) printf "%-22s = %s\n", key, value
		}
	' "$SPICE_CONFIG" > "$tmp"
	mv "$tmp" "$SPICE_CONFIG"
}

# --- dependencies (Homebrew) ------------------------------------------------
install_deps() {
	if ! command -v brew >/dev/null 2>&1; then
		warn "Homebrew not found. Install it from https://brew.sh then re-run."
		return 1
	fi
	info "Installing dependencies from Brewfile..."
	brew bundle --file="$REPO_DIR/Brewfile"
}

if ! install_deps; then
	warn "Dependency installation failed; fix the Homebrew error above and re-run."
	exit 1
fi

[ "$DEPS_ONLY" -eq 1 ] && {
	info "Dependencies installed. Done (--deps-only)."
	exit 0
}

# --- sketchybar config ------------------------------------------------------
deploy "$REPO_DIR/sketchybar/.config/sketchybar" "$HOME/.config/sketchybar"
# plugin scripts must stay executable
find "$HOME/.config/sketchybar" -name '*.sh' -exec chmod +x {} +

# --- kitty config + themes --------------------------------------------------
deploy "$REPO_DIR/kitty/.config/kitty" "$HOME/.config/kitty"

# --- tmux -------------------------------------------------------------------
deploy "$REPO_DIR/tmux.conf" "$HOME/.tmux.conf"

# --- oh-my-zsh theme --------------------------------------------------------
ZSH_CUSTOM="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}"
if [ -d "${ZSH:-$HOME/.oh-my-zsh}" ]; then
	for theme in "$REPO_DIR"/ohmyzsh/custom/themes/*.zsh-theme; do
		[ -e "$theme" ] || continue
		deploy "$theme" "$ZSH_CUSTOM/themes/$(basename "$theme")"
	done
else
	warn "oh-my-zsh not found at ${ZSH:-$HOME/.oh-my-zsh}; skipping theme. Set ZSH_THEME in ~/.zshrc after installing it."
fi

# --- fonts ------------------------------------------------------------------
FONT_DIR="$HOME/Library/Fonts"
mkdir -p "$FONT_DIR"
for f in "$REPO_DIR"/fonts/*.ttf; do
	[ -e "$f" ] || continue
	cp "$f" "$FONT_DIR/"
	info "installed font $(basename "$f")"
done

# --- wallpaper --------------------------------------------------------------
WALLPAPER_SRC=""
for f in "$REPO_DIR"/wallpapers/current-wallpaper.*; do
	[ -e "$f" ] || continue
	WALLPAPER_SRC="$f"
	break
done

if [ -n "$WALLPAPER_SRC" ]; then
	WALLPAPER_DIR="$HOME/Pictures/taro-rice"
	mkdir -p "$WALLPAPER_DIR"
	WALLPAPER_DEST="$WALLPAPER_DIR/$(basename "$WALLPAPER_SRC")"
	cp "$WALLPAPER_SRC" "$WALLPAPER_DEST"
	info "installed wallpaper $(basename "$WALLPAPER_DEST")"

	osascript <<OSA >/dev/null 2>&1 || warn "Could not apply wallpaper automatically; set $WALLPAPER_DEST manually from System Settings."
tell application "System Events"
	set picture of every desktop to "$WALLPAPER_DEST"
end tell
OSA
fi

# --- spicetify (themed Spotify) ---------------------------------------------
# The Marketplace-applied theme's CSS lives in Spotify's localStorage and cannot
# be carried in dotfiles, so we transport the config + local Themes/Extensions,
# (re)install the Marketplace custom app, then apply. Pick your theme again from
# the Marketplace tab in Spotify afterwards.
if command -v spicetify >/dev/null 2>&1; then
	SPICE_DIR="$HOME/.config/spicetify"
	SPICE_CONFIG="$SPICE_DIR/config-xpui.ini"
	mkdir -p "$SPICE_DIR"

	# Generate a baseline config + back up Spotify so spicetify knows the paths.
	spicetify backup apply >/dev/null 2>&1 || spicetify >/dev/null 2>&1 || true

	if [ ! -f "$SPICE_CONFIG" ]; then
		warn "Spicetify did not create $SPICE_CONFIG; skipping Spicetify config apply. Open Spotify once, then run 'spicetify backup apply'."
	else
		# Apply only portable settings and preserve the generated [Backup] section,
		# which is specific to this machine's Spotify + Spicetify versions.
		backup "$SPICE_CONFIG"
		set_spicetify_config spotify_path "/Applications/Spotify.app/Contents/Resources"
		set_spicetify_config prefs_path "$HOME/Library/Application Support/Spotify/prefs"
		set_spicetify_config color_scheme ""
		set_spicetify_config inject_theme_js 1
		set_spicetify_config replace_colors 1
		set_spicetify_config overwrite_assets 0
		set_spicetify_config spotify_launch_flags ""
		set_spicetify_config current_theme marketplace
		set_spicetify_config inject_css 1
		set_spicetify_config check_spicetify_update 1
		set_spicetify_config always_enable_devtools 0
		set_spicetify_config remove_rtl_rule 1
		set_spicetify_config expose_apis 1
		set_spicetify_config disable_sentry 1
		set_spicetify_config disable_ui_logging 1
		set_spicetify_config extensions ""
		set_spicetify_config custom_apps marketplace
		set_spicetify_config sidebar_config 0
		set_spicetify_config home_config 1
		set_spicetify_config experimental_features 1
	fi

	for d in Themes Extensions; do
		merge_dir "$REPO_DIR/spicetify/$d" "$SPICE_DIR/$d"
	done

	# Install the Marketplace custom app if it's referenced but missing.
	if grep -q 'marketplace' "$SPICE_CONFIG" 2>/dev/null &&
		[ ! -d "$SPICE_DIR/CustomApps/marketplace" ]; then
		info "Installing Spicetify Marketplace..."
		curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.sh | sh >/dev/null 2>&1 || warn "Marketplace install failed; install it manually later."
	fi

	spicetify apply >/dev/null 2>&1 || warn "spicetify apply failed; open Spotify once, then run 'spicetify backup apply'."
	info "spicetify configured."
else
	warn "spicetify not found; skipping. Install it then re-run, or run 'spicetify backup apply'."
fi

# --- start / reload sketchybar ----------------------------------------------
if command -v brew >/dev/null 2>&1 && brew list sketchybar >/dev/null 2>&1; then
	brew services restart sketchybar >/dev/null 2>&1 || sketchybar --reload || true
	info "sketchybar (re)started."
fi

info "Done. New machine notes:"
cat <<'EOF'
  - Set ZSH_THEME="catppuccin-mocha" in ~/.zshrc and run `source ~/.zshrc`.
  - Launch Amethyst and grant Accessibility permission (drives the Spaces shown in the bar).
  - Grant sketchybar Accessibility/Automation permission so media + space plugins work.
  - If any glyphs render as boxes, confirm "CaskaydiaCove Nerd Font" and "SF Pro" are installed.
  - Open Spotify, then re-pick your theme from the Spicetify Marketplace tab (Marketplace
    themes are stored in Spotify's localStorage and cannot be carried in dotfiles).
EOF
