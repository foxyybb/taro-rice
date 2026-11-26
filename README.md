# dotfiles / rice

macOS desktop rice — Catppuccin-themed SketchyBar, tmux, and oh-my-zsh, packaged
for transport between machines.

## Contents

| Component | Source | Destination |
|-----------|--------|-------------|
| SketchyBar config | `sketchybar/.config/sketchybar/` | `~/.config/sketchybar/` |
| Kitty config/themes | `kitty/.config/kitty/` | `~/.config/kitty/` |
| tmux | `tmux.conf` | `~/.tmux.conf` |
| oh-my-zsh theme | `ohmyzsh/custom/themes/*.zsh-theme` | `$ZSH_CUSTOM/themes/` |
| Spicetify config/template | `spicetify/` | `~/.config/spicetify/` |
| App icon font | `fonts/*.ttf` | `~/Library/Fonts/` |
| Wallpaper | `wallpapers/current-wallpaper.png` | `~/Pictures/taro-rice/` |

## Install

```sh
git clone <this-repo> ~/rice && cd ~/rice
./install.sh
```

The script installs dependencies via Homebrew (`Brewfile`), backs up any existing
files to `~/.rice-backup/<timestamp>/`, deploys the configs, installs the fonts,
copies and applies the wallpaper, applies portable Spicetify settings without
replacing Spicetify's machine-local backup metadata, and (re)starts SketchyBar.

### Options

| Flag | Effect |
|------|--------|
| `--link` | Symlink configs instead of copying (edits track the repo) |
| `--no-backup` | Overwrite existing files without backing them up |
| `--deps-only` | Only run `brew bundle` |

## Dependencies

Installed by `brew bundle` (see `Brewfile`): `sketchybar`, `jq`, `ifstat`,
`tmux`, Kitty, `spicetify-cli`, Spotify, CaskaydiaCove Nerd Font, SF Pro, and
Amethyst.

## Post-install

- Set `ZSH_THEME="catppuccin-mocha"` in `~/.zshrc`, then `source ~/.zshrc`.
- Launch **Amethyst** and grant Accessibility permission — it drives the native
  Spaces shown in the bar.
- Grant **SketchyBar** Accessibility/Automation permission so the media and
  space-window plugins work.
- If glyphs render as boxes, confirm **CaskaydiaCove Nerd Font** and **SF Pro**
  are installed.
- Open **Spotify**, then re-select your theme from the **Spicetify Marketplace**
  tab. Marketplace themes are stored in Spotify's localStorage, so only the
  Spicetify config and local themes/extensions transport via dotfiles.

## Per-machine Overrides

The network meter follows the interface backing the default route. To pin a
specific interface on one machine, copy the example config after installing:

```sh
cp ~/.config/sketchybar/plugins/local_config.example.sh ~/.config/sketchybar/plugins/local_config.sh
```

Then edit `NETWORK_IFACE` in `local_config.sh` (for example, `en7`). That file is
ignored by git so device-specific interface names do not leak into the package.

## Checking WindowServer port growth

Run `./scripts/check-windowserver.sh` for a read-only ten-minute sample (or pass
a duration in seconds). Compare samples on the **same WindowServer PID**, with
similar activity and playback state. It reports total ports and new GUI client
connections; when run as root it also counts dead-name port entries. The script
never requests administrator access. Look for the **growth rate**, not an
immediate drop: changing the bar doesn't reclaim names already leaked.

The media item listens to Spotify and Music playback notifications. A refresh
or click can still start one `osascript`; idle or paused playback should not
start one every three seconds. Window icons use the native `space_windows_change`
payload for each Space, including the initial snapshots from
`sketchybar --update`. A separate 15-second badge check reads Discord's LaunchServices
status without enumerating windows. Other apps can still open GUI connections.

For an A/B comparison, temporarily pause **one** item's script with
`sketchybar --set media.cover updates=off` or
`sketchybar --set space_watcher updates=off`. Restore the item with `updates=on`
and run `sketchybar --update`
before the next sample. For copy-mode installs, deploy the edited SketchyBar
files to `~/.config/sketchybar/` and run `sketchybar --reload`; the full
installer isn't needed for this check.
