# nix-rerune

Nix flake for the [ReRune](https://rerune.io) CLI. It packages the prebuilt `rerune` binaries from the official release mirror ([BasalBit/rerune-releases](https://github.com/BasalBit/rerune-releases)) for `x86_64-linux`, `aarch64-linux`, `x86_64-darwin` and `aarch64-darwin`. The same repository is also a [NUR](https://github.com/nix-community/NUR) repository.

## Install

Try it without installing:

```sh
nix run github:BasalBit/nix-rerune -- version
```

Install it into your profile:

```sh
nix profile install github:BasalBit/nix-rerune
```

Upgrade a profile install with `nix profile upgrade --all`. This is also what `rerune update` prints for a profile install.

### NixOS, nix-darwin and Home Manager

Add the flake input:

```nix
rerune.url = "github:BasalBit/nix-rerune";
```

Then add the package to `environment.systemPackages` or `home.packages`:

```nix
inputs.rerune.packages.${pkgs.stdenv.hostPlatform.system}.default
```

Upgrade with `nix flake update rerune`, then rebuild the configuration. `rerune update` prints `nix flake update rerune` for an installation that does not come from a Nix profile.

The flake also exports `overlays.default`, which adds `rerune` to your package set.

### NUR

A pull request adds this repository to NUR as `basalbit`. Once NUR lists it, the package is `nur.repos.basalbit.rerune`.

## What the package contains

`pkgs/rerune/default.nix` downloads the release archive for your system with `fetchurl`, pinned to the SHA-256 in the release's `checksums.txt`, and installs `bin/rerune`, the MIT license and the README. The binary is not stripped, patched or re-signed (`dontFixup = true`), so it stays byte-identical to the published executable and the ad-hoc code signature of the Apple silicon binary stays valid. The Linux binaries are static Go executables, so they need no ELF patching on NixOS. The build runs `rerune version` and fails unless it prints the packaged version.

The store path is `/nix/store/<hash>-rerune-<version>/bin/rerune`, which is how `rerune update` recognizes a Nix installation.

## Pinned nixpkgs

`nixpkgs` follows `nixpkgs-unstable`, the branch NUR evaluates against and the only branch that is built and cached for both Linux and `aarch64-darwin`. Nixpkgs dropped `x86_64-darwin` from unstable after 26.05, so that system builds with its own input, `nixpkgs-x86_64-darwin`, pinned to `nixpkgs-26.05-darwin` (the last release that supports it) with `allowDeprecatedx86_64Darwin`. The package needs only `stdenvNoCC` and `fetchurl`, so you can let it follow your own nixpkgs:

```nix
rerune.inputs.nixpkgs.follows = "nixpkgs";
```

## How releases reach this repository

This repository is generated. Its source of truth is `packaging/nix/` in the ReRune CLI repository, and every file here is replaced on each release, so please open issues rather than pull requests for packaging changes.

1. For each stable tag `vX.Y.Z`, the CLI release workflow renders `pkgs/rerune/default.nix` from the release mirror's `checksums.txt`, downloads every archive and compares its SHA-256, and pushes the new tree as one commit on top of `main` to the `staging` branch.
2. The `ci` workflow builds and runs the package on `ubuntu-latest` (`x86_64-linux`), `ubuntu-24.04-arm` (`aarch64-linux`), `macos-latest` (`aarch64-darwin`) and `macos-26-intel` (`x86_64-darwin`). Each job runs `nix flake check --all-systems`, `nix build`, `rerune version`, `nix run`, a `nix profile install` and upgrade, compares the store binary with the release's `binary-checksums.txt`, checks the store path against the `rerune update` pattern, verifies the ad-hoc code signature on Apple silicon (the Go linker signs only arm64 binaries; Intel macOS runs unsigned ones), and runs `rerune update`. The Linux and Apple silicon jobs also evaluate the repository the way NUR does (`ci/nur-eval.sh`).
3. The CLI release workflow waits for that run. Only when every job is green does it fast-forward `main` to exactly the tested commit and create the tag `vX.Y.Z`, in one atomic push. It refuses when the tag already points at another commit, and a failed run leaves `main` and the tags untouched. It then asks NUR to refresh `basalbit`; NUR also polls daily, so a failed request is only a warning.

The `ci` workflow only reads the repository: pull requests run the same test matrix, and nothing in this repository can move `main`. `main` and the `v*` tags are protected against deletion, force-pushes and tag updates.

## License

MIT, see [LICENSE](LICENSE). ReRune CLI itself is MIT licensed by BasalBit GmbH.
