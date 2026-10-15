{pkgs ? import <nixpkgs> {}}:
pkgs.rustPlatform.buildRustPackage {
  pname = "inferno-aoip";
  version = "0.5.0";

  src = pkgs.fetchgit {
    url = "https://gitlab.com/lumifaza/inferno";
    rev = "9767558e0905c9e9c960f5a60e050fbdc38300b7";
    fetchSubmodules = true;
    hash = "sha256-tbJu/B0lEUTOEBpOGFoA6UaT9TOeMD44gI6x9elHNq0=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  cargoBuildFlags = ["--workspace"];

  nativeBuildInputs = [pkgs.pkg-config];
  buildInputs = [pkgs.alsa-lib];

  doCheck = false;

  installPhase = ''
    runHook preInstall
    releaseDir=$(find target -mindepth 2 -maxdepth 3 -name release -type d | head -1)
    install -Dm755 "$releaseDir/inferno2pipe" $out/bin/inferno2pipe
    so=$(find "$releaseDir" -maxdepth 1 -name 'libasound_module_pcm_inferno.so' | head -1)
    install -Dm755 "$so" $out/lib/alsa-lib/libasound_module_pcm_inferno.so
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Unofficial Dante AoIP implementation — ALSA virtual soundcard and capture tool";
    license = with licenses; [gpl3Plus];
    mainProgram = "inferno2pipe";
  };
}
