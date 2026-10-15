{pkgs ? import <nixpkgs> {}}:
pkgs.rustPlatform.buildRustPackage {
  pname = "statime-inferno";
  version = "0.4.0";

  src = pkgs.fetchgit {
    url = "https://github.com/teodly/statime";
    rev = "244f20a56c173b1881f2e5e83652bb8b8209b2ab";
    fetchSubmodules = true;
    hash = "sha256-4xlJUGbtumQCFDqMdV87xDIjIcG0f6YvmwrEWHFeXwc=";
  };

  cargoBuildFlags = ["--package" "statime-linux"];

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "usrvclock-0.1.1" = "sha256-a9VfCP6RUeRTOZl2K52X/fm709W+n/jijoQ4nVE2V3M=";
    };
  };

  doCheck = false;

  meta = with pkgs.lib; {
    description = "PTP clock daemon fork with PTPv1 support for Dante/Inferno AoIP";
    license = with licenses; [mit asl20];
    mainProgram = "statime";
  };
}
