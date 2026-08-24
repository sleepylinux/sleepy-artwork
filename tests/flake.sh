#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
flake="$repository_root/flake.nix"

contains_top_level_inherit() {
  awk '
    BEGIN {
      single_quote = sprintf("%c", 39)
    }

    function identifier_character(character) {
      return character ~ /[[:alnum:]_-]/ || character == single_quote
    }

    function finish_word() {
      if (word == "inherit" && word_depth == 1) {
        found = 1
      }
      word = ""
    }

    {
      for (position = 1; position <= length($0); position++) {
        character = substr($0, position, 1)
        next_character = substr($0, position + 1, 1)

        if (block_comment_depth > 0) {
          if (character == "/" && next_character == "*") {
            block_comment_depth++
            position++
          } else if (character == "*" && next_character == "/") {
            block_comment_depth--
            position++
          }
          continue
        }

        if (in_double_quoted_string) {
          if (escaped) {
            escaped = 0
          } else if (character == "\\") {
            escaped = 1
          } else if (character == "\"") {
            in_double_quoted_string = 0
          }
          continue
        }

        if (in_indented_string) {
          if (character == single_quote && next_character == single_quote) {
            following_character = substr($0, position + 2, 1)
            if (following_character != single_quote &&
                following_character != "$" && following_character != "\\") {
              in_indented_string = 0
            }
            position++
          }
          continue
        }

        if (character == "#") {
          finish_word()
          break
        }
        if (character == "/" && next_character == "*") {
          finish_word()
          block_comment_depth++
          position++
          continue
        }
        if (character == "\"") {
          finish_word()
          in_double_quoted_string = 1
          continue
        }
        if (character == single_quote && next_character == single_quote) {
          finish_word()
          in_indented_string = 1
          position++
          continue
        }

        if (identifier_character(character)) {
          if (word == "") {
            word_depth = brace_depth
          }
          word = word character
          continue
        }

        finish_word()
        if (character == "{") {
          brace_depth++
        } else if (character == "}") {
          brace_depth--
        }
      }
      finish_word()
    }

    END {
      exit found ? 0 : 1
    }
  '
}

if ! rg -q '^      checks = forAllSystems \(system:' "$flake"; then
  printf 'FAIL: flake.nix must export per-system checks\n' >&2
  exit 1
fi

checks_attrset="$(
  sed -n '/^      checks = forAllSystems (system:/,/^        });$/p' "$flake" |
    sed -n '/^        {$/,/^        });$/p'
)"

if contains_top_level_inherit <<< "$checks_attrset"; then
  printf 'FAIL: per-system flake checks must not use top-level inherit\n' >&2
  exit 1
fi

mapfile -t check_names < <(
  sed -nE \
    -e 's/^          ([A-Za-z_][A-Za-z0-9_-]*)[[:space:]]*=.*/\1/p' \
    -e 's/^          "([^"]+)"[[:space:]]*=.*/\1/p' \
    <<< "$checks_attrset"
)

if (( ${#check_names[@]} != 1 )) || [[ "${check_names[0]:-}" != assets ]]; then
  printf 'FAIL: per-system flake checks must expose exactly assets, found: %s\n' \
    "${check_names[*]:-(none)}" >&2
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
