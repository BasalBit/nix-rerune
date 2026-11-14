#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 0 ] || {
  printf 'Usage: %s\n' "$0" >&2
  exit 2
}

nur_commit=02ada640e7e277e0909c15108ed59056049b8e5f
eval_repo_sha256=97064f84930a7fc150cf649768463e839a950468fc51a81eb56b11896c1aa456

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
work_directory=$(mktemp -d "${TMPDIR:-/tmp}/nix-rerune-nur.XXXXXX")
trap 'rm -rf "$work_directory"' EXIT
work_directory=$(cd "$work_directory" && pwd -P)

nix_command() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
}

curl --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 10 \
  --output "$work_directory/evalRepo.nix" \
  "https://raw.githubusercontent.com/nix-community/NUR/$nur_commit/lib/evalRepo.nix"
if command -v sha256sum >/dev/null 2>&1; then
  downloaded_sha256=$(sha256sum "$work_directory/evalRepo.nix" | awk '{ print $1 }')
else
  downloaded_sha256=$(shasum -a 256 "$work_directory/evalRepo.nix" | awk '{ print $1 }')
fi
[ "$downloaded_sha256" = "$eval_repo_sha256" ] || fail "NUR lib/evalRepo.nix at $nur_commit has sha256 $downloaded_sha256, expected $eval_repo_sha256"

nixpkgs_path=$(cd "$repository_root" && nix_command flake archive --json | jq -r '.inputs.nixpkgs.path')
[ -d "$nixpkgs_path" ] || fail "Could not locate the locked nixpkgs input: $nixpkgs_path"

jq -n --arg src "$repository_root/default.nix" \
  '{name: "basalbit", url: "https://github.com/BasalBit/nix-rerune", src: $src}' > "$work_directory/args.json"
cat > "$work_directory/default.nix" <<'EOF'
with import <nixpkgs> {};
let
  args = builtins.fromJSON (builtins.readFile ./args.json);
in
import ./evalRepo.nix {
  inherit (args) name url;
  src = /. + args.src;
  inherit pkgs lib;
}
EOF

env -u NIX_PATH NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix-env \
  -f "$work_directory/default.nix" \
  -qa '*' \
  --meta \
  --json \
  --allowed-uris https://static.rust-lang.org \
  --option restrict-eval true \
  --option allow-import-from-derivation true \
  --drv-path \
  --show-trace \
  -I "nixpkgs=$nixpkgs_path" \
  -I "$repository_root" \
  -I "$work_directory/default.nix" \
  -I "$work_directory/args.json" \
  -I "$work_directory/evalRepo.nix" > "$work_directory/packages.json"

version=$(nix_command eval --raw "$repository_root#packages.$(nix_command eval --impure --raw --expr builtins.currentSystem).default.version")
jq -e --arg name "rerune-$version" '.rerune.name == $name and (.rerune.drvPath | startswith("/nix/store/"))' "$work_directory/packages.json" >/dev/null \
  || fail "The NUR evaluation did not list rerune-$version: $(cat "$work_directory/packages.json")"
jq -e '.rerune.meta.license.spdxId == "MIT" and .rerune.meta.mainProgram == "rerune"' "$work_directory/packages.json" >/dev/null \
  || fail 'The NUR evaluation lost the MIT license or mainProgram'
printf 'NUR evaluation lists %s\n' "$(jq -r '[.[] | .name] | join(", ")' "$work_directory/packages.json")"
