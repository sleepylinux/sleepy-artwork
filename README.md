# sleepy-artwork

## License

Licensed under GPL-3.0-only. See [LICENSE](LICENSE).

Versioned artwork assets for Sleepy.

`branding/manifest.json` maps logical asset names to package-relative files.
The primary mark is available as `branding.primaryMark` and installs at
`share/sleepy-artwork/branding/logo.svg`.

Control Center artwork uses logical names so consumers do not depend on source
paths. The set includes:

- `icons.control-center`, `icons.network`, `icons.bluetooth`, `icons.volume`
- `icons.microphone`, `icons.brightness`, `icons.night-light`, `icons.focus`
- `icons.battery`, `icons.power-profile`, `icons.preset`, `icons.keybinding`
- `icons.media-play`, `icons.media-pause`, `icons.media-next`, `icons.media-previous`
- `icons.lock`, `icons.logout`, and `icons.power`

All icons install below `share/sleepy-artwork/icons/`. They are 24x24 SVGs
drawn with two-pixel rounded `currentColor` strokes, allowing the desktop to
apply theme colors without maintaining alternate asset copies.

## Verify

```sh
bash tests/manifest.sh
```

## Package

```sh
nix build .#sleepy-artwork
```
