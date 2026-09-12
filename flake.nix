{
  description = "push-notification-server.rs Rust environment with SOPS, age, and Just";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ores-sops.url = "github:ORESoftware/ores-sops";
  };

  outputs =
    { self, nixpkgs, ores-sops, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages =
              (with pkgs; [
                age
                cargo
                clippy
                git
                jq
                just
                nixfmt-rfc-style
                openssl
                pkg-config
                python3
                rust-analyzer
                rustc
                rustfmt
                sops
              ])
              ++ [ ores-sops.packages.${system}.default ];

            RUST_BACKTRACE = "1";

            shellHook = ''
              export NIX_DEV_SHELL=push-notification-server-rs
              ${ores-sops.lib.shellHook}
            '';
          };
        }
      );
    };
}
