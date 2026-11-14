#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s SYSTEM\n' "$0" >&2
  exit 2
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 1 ] || usage

system=$1
store_executable_pattern='^/nix/store/[a-z0-9]{32}-rerune-[^/]+/bin/rerune$'
mirror_url=https://raw.githubusercontent.com/BasalBit/rerune-releases/main
case "$system" in
  x86_64-linux) target=linux_amd64 ;;
  aarch64-linux) target=linux_arm64 ;;
  x86_64-darwin) target=darwin_amd64 ;;
  aarch64-darwin) target=darwin_arm64 ;;
  *) fail "Unsupported system $system" ;;
esac

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repository_root"
work_directory=$(mktemp -d "${TMPDIR:-/tmp}/nix-rerune-check.XXXXXX")
trap 'rm -rf "$work_directory"' EXIT
work_directory=$(cd "$work_directory" && pwd -P)

nix_command() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
}

host_system=$(nix_command eval --impure --raw --expr builtins.currentSystem)
[ "$host_system" = "$system" ] || fail "This host builds $host_system, not $system"

version=$(nix_command eval --raw ".#packages.$system.default.version")
printf '%s\n' "$version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' || fail "Unexpected package version '$version'"
printf 'Checking rerune %s on %s\n' "$version" "$system"

nix_command flake check --all-systems --print-build-logs

nix_command build --print-build-logs --out-link "$work_directory/result" ".#packages.$system.default"
store_executable=$(readlink -f "$work_directory/result/bin/rerune")
printf '%s\n' "$store_executable" | grep -Eq "$store_executable_pattern" \
  || fail "$store_executable does not match the rerune update pattern $store_executable_pattern"
printf 'Store path %s matches %s\n' "$store_executable" "$store_executable_pattern"

[ "$("$work_directory/result/bin/rerune" version)" = "$version" ] || fail "result/bin/rerune version does not print $version"
[ "$(nix_command run . -- version)" = "$version" ] || fail "nix run . -- version does not print $version"
[ "$(nix_command run ".#rerune" -- version)" = "$version" ] || fail "nix run .#rerune -- version does not print $version"

curl --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 10 \
  --output "$work_directory/binary-checksums.txt" "$mirror_url/v$version/binary-checksums.txt"
published_sha256=$(awk -v member="rerune_${version}_${target}/rerune" '$2 == member { print $1 }' "$work_directory/binary-checksums.txt")
[ -n "$published_sha256" ] || fail "binary-checksums.txt has no rerune_${version}_${target}/rerune"
if command -v sha256sum >/dev/null 2>&1; then
  store_sha256=$(sha256sum "$store_executable" | awk '{ print $1 }')
else
  store_sha256=$(shasum -a 256 "$store_executable" | awk '{ print $1 }')
fi
[ "$store_sha256" = "$published_sha256" ] || fail "The store binary has sha256 $store_sha256, the published executable $published_sha256"
printf 'The store binary is byte-identical to the published %s executable\n' "$target"

if [ "$system" = aarch64-darwin ]; then
  codesign --verify --strict --verbose=2 "$store_executable"
fi

profile=$work_directory/profile
nix_command profile install --profile "$profile" .
[ "$(readlink -f "$profile/bin/rerune")" = "$store_executable" ] || fail 'nix profile install did not link the built rerune'
nix_command profile upgrade --profile "$profile" --all
[ "$("$profile/bin/rerune" version)" = "$version" ] || fail "the profile rerune does not print $version"

if [ "$(id -u)" -eq 0 ]; then
  printf 'Skipping the rerune update check: rerune update refuses to run as root\n'
else
  update_home=$work_directory/home
  mkdir -p "$update_home"
  ln -s "$profile" "$update_home/.nix-profile"
  check_update() {
    local invoked=$1 expected_command=$2 status=0
    HOME=$update_home "$invoked" update > "$work_directory/update.txt" 2>&1 || status=$?
    cat "$work_directory/update.txt"
    case $status in
      0) grep -Fq "ReRune v$version is already up to date." "$work_directory/update.txt" || fail "rerune update from $invoked exited 0 without the up-to-date message" ;;
      2) grep -Fxq "  $expected_command" "$work_directory/update.txt" || fail "rerune update from $invoked did not print $expected_command" ;;
      *) fail "rerune update from $invoked exited $status" ;;
    esac
  }
  check_update "$update_home/.nix-profile/bin/rerune" 'nix profile upgrade --all'
  check_update "$work_directory/result/bin/rerune" 'nix flake update rerune'
fi

printf 'rerune %s passed the Nix checks on %s\n' "$version" "$system"
