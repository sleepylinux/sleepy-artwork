{
  description = "Versioned Sleepy artwork assets";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        rec {
          sleepy-artwork = pkgs.stdenvNoCC.mkDerivation {
            pname = "sleepy-artwork";
            version = "0.1.0";
            src = ./.;

            installPhase = ''
              install -Dm644 branding/logo.svg "$out/share/sleepy-artwork/branding/logo.svg"
              install -Dm644 branding/manifest.json "$out/share/sleepy-artwork/branding/manifest.json"
              install -d "$out/share/sleepy-artwork/icons"
              install -m644 icons/*.svg "$out/share/sleepy-artwork/icons/"
            '';

            meta.license = pkgs.lib.licenses.gpl3Only;
          };

          default = sleepy-artwork;
        });
    };
}
