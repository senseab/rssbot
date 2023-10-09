{
  description = "Lightweight Telegram RSS notification bot.";

  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };


  outputs = {self, nixpkgs, utils, fenix}:
    utils.lib.eachDefaultSystem
    (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [fenix.overlays.default];
        };
        toolchain = pkgs.fenix.complete;
        lang = "zh";
      in
      rec {
        packages.default = (pkgs.makeRustPlatform{
          inherit (toolchain) cargo rustc;
        }).buildRustPackage {
          pname = "rssbot";
          version = "2.0.0-alpha.12";
          src = ./.;
          cargoLock = {
            lockFile = ./Cargo.lock;
            outputHashes = {
              "tbot-0.6.7" = "sha256-3WJ5m8hyNug1RwFVLUmAyQPQjL9xc++hCHgfrIM4piM=";
            };
          };

          LOCALE = lang;
        };

        apps.default = utils.lib.mkApp {drv = packages.default;};

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (with toolchain; [
              rustup
            ])
            pkg-config
            fish
          ];

          RUST_SRC_PATH = "${toolchain.rust-src}/lib/rustlib/src/rust/library";

          shellHook = ''
            export LOCALE=`echo $LANG | cut -b 1-2`
            echo "cargo = `${pkgs.rustup}/bin/cargo --version`"
            exec fish
          '';
        };

        nixosModules.default = {config, pkgs, lib, ...}: with lib; 
        let 
          cfg = config.services.rssbot;
        in {
          options.services.rssbot = {
            enable = mkEnableOption "rssbot service";
            token = mkOption {
              type = types.str;
              example = "12345678:AAAAAAAAAAAAAAAAAAAAAAAAATOKEN";
              description = lib.mdDoc "Telegram bot token";
            };
            tgUri = mkOption {
              type = types.str;
              default = "https://api.telegram.org";
              example = "https://api.telegram.org";
              description = lib.mdDoc "Custom telegram api URI";
            };
            extraOptions = mkOption {
              type = types.str;
              description = lib.mdDoc "Extra option for bot.";
            };
          };
          config = let 
            args = "${cfg.extraOptions} ${if isString cfg.tgUri then "--api-uri ${escapeShellArg cfg.tgUri}" else ""}"; 
          in mkIf cfg.enable {
            systemd.services.rssbot = {
              wantedBy = [ "multi-user.target" ];
              serviceConfig.ExecStart = "${pkgs.rssbot}/bin/rssbot ${args} ${escapeShellArg cfg.token}";
            };
          };
        };
      }
    );
}