# sleepy-artwork

Versioned artwork assets for Sleepy.

`branding/manifest.json` maps logical asset names to package-relative files.
The primary mark is available as `branding.primaryMark` and installs at
`share/sleepy-artwork/branding/logo.svg`.

## Verify

```sh
bash tests/manifest.sh
```

## Package

```sh
nix build .#sleepy-artwork
```
