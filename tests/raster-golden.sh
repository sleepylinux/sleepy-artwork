#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

actual="$tmp_dir/actual.sha256"
for svg in "$repo_root"/branding/*.svg "$repo_root"/icons/*.svg; do
  relative="${svg#"$repo_root"/}"
  png="$tmp_dir/${relative//\//_}.png"
  rsvg-convert --width 64 --height 64 --keep-aspect-ratio "$svg" >"$png"
  test -s "$png"
  sha256sum "$png" | cut -d' ' -f1
done | sha256sum | cut -d' ' -f1 >"$actual"

cmp "$repo_root/tests/raster-golden.sha256" "$actual"
printf 'PASS: SVG raster output matches the reviewed golden\n'
