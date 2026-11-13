{
  description = "Development shell for Tsujiura";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # lambroll is not packaged in nixpkgs.
      lambroll = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "lambroll";
        version = "1.6.1";
        src = pkgs.fetchurl {
          url = "https://github.com/fujiwara/lambroll/releases/download/v${version}/lambroll_v${version}_linux_amd64.tar.gz";
          sha256 = "bf3761c879026d161e350c2e9196e8cbb557e2d2cf8ef7be7575e10f54116c41";
        };
        sourceRoot = ".";
        installPhase = ''
          install -Dm755 lambroll $out/bin/lambroll
        '';
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          awscli2
          dig
          go
          google-cloud-sdk
          jq
          just
          lambroll
          lefthook
          terraform
        ];
      };
    };
}
