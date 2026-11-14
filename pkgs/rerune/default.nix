{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "1.0.23";
  sources = {
    x86_64-linux = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.23/rerune_1.0.23_linux_amd64.tar.gz";
      sha256 = "1ef615c9865b819ff846c3ab7b913ab0d9bcc252d78d2492424d256623b635fe";
    };
    aarch64-linux = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.23/rerune_1.0.23_linux_arm64.tar.gz";
      sha256 = "0ffc2dc5a57343e9cd20d61d5842fb991430d4a21edc23ad5bdd37dc2eb88e09";
    };
    x86_64-darwin = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.23/rerune_1.0.23_darwin_amd64.tar.gz";
      sha256 = "f8e6da4a9c8d618b8911e92d2c3720817aa245f2e522610eb6244402fdd444ed";
    };
    aarch64-darwin = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.23/rerune_1.0.23_darwin_arm64.tar.gz";
      sha256 = "05e890ba9fc166a4eefe54cf26f37c6a417300717082c03b39d5fe3d2b50beb1";
    };
  };
  system = stdenvNoCC.hostPlatform.system;
in
stdenvNoCC.mkDerivation {
  pname = "rerune";
  inherit version;

  src = sources.${system} or (throw "rerune ${version} has no prebuilt binary for ${system}");

  dontConfigure = true;
  dontBuild = true;
  # The release binary must stay byte-identical to the published executable:
  # stripping or patching would break the ad-hoc code signature on darwin, and
  # the static Linux binary needs no ELF patching.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 rerune "$out/bin/rerune"
    install -Dm644 LICENSE "$out/share/licenses/rerune/LICENSE"
    install -Dm644 README.md "$out/share/doc/rerune/README.md"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    reported_version=$("$out/bin/rerune" version)
    if [ "$reported_version" != "${version}" ]; then
      echo "rerune version printed '$reported_version', expected '${version}'" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "CLI for rerune translation workflows";
    homepage = "https://rerune.io";
    downloadPage = "https://github.com/BasalBit/rerune-releases";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "rerune";
    platforms = builtins.attrNames sources;
  };
}
