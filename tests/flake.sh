#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
flake="$repository_root/flake.nix"

if ! rg -q '^      checks = forAllSystems \(system:' "$flake"; then
  printf 'FAIL: flake.nix must export per-system checks\n' >&2
  exit 1
fi

if ! rg -q 'bash tests/manifest\.sh' "$flake" || \
  ! rg -q 'bash tests/manifest-security-test\.sh' "$flake"; then
  printf 'FAIL: a flake check must execute both manifest contracts\n' >&2
  exit 1
fi

if ! rg -q 'bash tests/license\.sh' "$flake"; then
  printf 'FAIL: a flake check must execute the license contract\n' >&2
  exit 1
fi

for dependency in bash coreutils gawk gnused jq libxml2 ripgrep; do
  if ! rg -q "pkgs\.$dependency" "$flake"; then
    printf 'FAIL: flake checks must provide the %s test dependency\n' "$dependency" >&2
    exit 1
  fi
done

printf 'PASS: flake exports checks that execute the artwork contracts\n'
