{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "1.0.22";
  sources = {
    x86_64-linux = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.22/rerune_1.0.22_linux_amd64.tar.gz";
      sha256 = "02f4a46e78c1f94dfc8f44b44ea0b1b449a67069e333cbbc6a0c54b0b0089dab";
    };
    aarch64-linux = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.22/rerune_1.0.22_linux_arm64.tar.gz";
      sha256 = "fb4dfa164e5cc2090d093360540de18c6f4d9e8b90058390da88530118d9185f";
    };
    x86_64-darwin = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.22/rerune_1.0.22_darwin_amd64.tar.gz";
      sha256 = "b88bc36d90719a325a970a558c3c3966fae0cf7385852aee6cdf7e8f5644a6ca";
    };
    aarch64-darwin = fetchurl {
      url = "https://raw.githubusercontent.com/BasalBit/rerune-releases/main/v1.0.22/rerune_1.0.22_darwin_arm64.tar.gz";
      sha256 = "89cbabe9d36ce07359928a22e57694da729a3848505f1ea5a42331caaf611d29";
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
