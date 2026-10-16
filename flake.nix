{
  description = "Cross-compile and package Unreal Engine 5.8 projects from Linux to Windows (Win64)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    runtimeDeps = with pkgs; [
      bash
      coreutils
      findutils
      gnugrep
      gnused
      patch
      jq
      xwin
      llvmPackages_20.clang-unwrapped
      llvmPackages_20.lld
      llvmPackages_20.bintools-unwrapped
    ];
  in {
    packages.${system} = {
      ue-linux-win64 = pkgs.stdenvNoCC.mkDerivation {
        pname = "ue-linux-win64";
        version = "0.1.0";
        src = self;
        nativeBuildInputs = [pkgs.makeWrapper];
        installPhase = ''
          mkdir -p $out/bin $out/patches $out/share/bash-completion/completions
          cp -r patches/* $out/patches/
          cp bin/ue-linux-win64 $out/bin/ue-linux-win64
          chmod +x $out/bin/ue-linux-win64
          cp bash_completion/ue-linux-win64 $out/share/bash-completion/completions/ue-linux-win64
          wrapProgram $out/bin/ue-linux-win64 \
            --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
        '';
      };
      default = self.packages.${system}.ue-linux-win64;
    };

    devShells.${system}.default = pkgs.mkShell {
      packages =
        runtimeDeps
        ++ [
          self.packages.${system}.ue-linux-win64
        ];
    };
  };
}
