#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-artwork-security.XXXXXX")"
trap 'rm -rf -- "$fixture_root"' EXIT

cp -R "$repository_root/branding" "$repository_root/icons" "$repository_root/tests" "$fixture_root/"
chmod -R u+w -- "$fixture_root"

icon="$fixture_root/icons/control-center.svg"
mutated_icon="$fixture_root/icons/control-center.mutated.svg"

assert_rejected() {
  local mutation="$1"
  local expected_error="$2"

  cp "$repository_root/icons/control-center.svg" "$icon"
  case "$mutation" in
    event-handler)
      awk 'NR == 1 { sub("<svg ", "<svg onload=\"alert(1)\" ") } { print }' "$icon" > "$mutated_icon"
      ;;
    style-attribute)
      awk 'NR == 1 { sub("<svg ", "<svg style=\"background:url(https://example.invalid/a)\" ") } { print }' "$icon" > "$mutated_icon"
      ;;
    script-element)
      awk '{ sub("</svg>", "<script/></svg>"); print }' "$icon" > "$mutated_icon"
      ;;
    animation-element)
      awk '{ sub("</svg>", "<animate attributeName=\"opacity\"/></svg>"); print }' "$icon" > "$mutated_icon"
      ;;
    href-attribute)
      awk 'NR == 1 { sub("<svg ", "<svg href=\"https://example.invalid/a\" ") } { print }' "$icon" > "$mutated_icon"
      ;;
  esac
  mv "$mutated_icon" "$icon"

  if output="$(bash "$fixture_root/tests/manifest.sh" 2>&1)"; then
    printf 'FAIL: manifest validation accepted the %s mutation\n' "$mutation" >&2
    exit 1
  fi

  if ! printf '%s\n' "$output" | rg -q "$expected_error"; then
    printf 'FAIL: %s mutation failed for the wrong reason:\n%s\n' "$mutation" "$output" >&2
    exit 1
  fi
}

assert_rejected event-handler 'event-handler attribute'
assert_rejected style-attribute 'unsupported SVG attribute'
assert_rejected script-element 'unsupported SVG element'
assert_rejected animation-element 'unsupported SVG element'
assert_rejected href-attribute 'unsupported SVG attribute'

printf 'PASS: manifest validation rejects executable SVG mechanisms\n'
