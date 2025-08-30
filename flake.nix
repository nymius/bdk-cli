{
  description = "bdk-cli - Bitcoin Dev Kit CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        # Define the Rust version we want to use
        rustVersion = pkgs.rust-bin.stable.latest.default;

        # Select which features to enable (default + electrum)
        features = [
          "repl"
          "sqlite"
          "rpc"
          "silent-payments"
        ];

        # Create a string of features for cargo
        featuresFlag = builtins.concatStringsSep "," features;
      in {
        formatter = pkgs.alejandra;

        packages = {
          # The bdk-cli package
          bdk-cli = pkgs.rustPlatform.buildRustPackage {
            pname = "bdk-cli";
            version = "1.0.0";

            src = ./.;

            cargoLock = {
              lockFile = ./Cargo.lock;

              outputHashes = {
                "bdk_sp-0.1.0" = "sha256-S5rT7cDh8skNn57xwOTZP5nFPPJF1xAXfJ6ZvVf6cJM=";
              };
            };

            # Enable the specified features
            buildFeatures = featuresFlag;

            # Required for sqlite feature
            nativeBuildInputs = with pkgs; [pkg-config];
            buildInputs = with pkgs; [openssl sqlite];

            # Libraries needed at runtime
            runtimeDependencies = with pkgs; [openssl.out sqlite];

            meta = with pkgs.lib; {
              description = "A lightweight command line bitcoin wallet powered by BDK";
              homepage = "https://bitcoindevkit.org";
              license = with licenses; [mit asl20];
              mainProgram = "bdk-cli";
            };
          };
        };
        # The default package
        defaultPackage = self.packages.${system}.bdk-cli;

        apps = {
          bdk-cli = flake-utils.lib.mkApp {
            drv = self.defaultPackage;
            name = "bdk-cli";
          };
        };

        devShells.default = pkgs.mkShell {
          name = "bdk-cli-dev";

          # Build inputs
          nativeBuildInputs = with pkgs; [
            rustVersion
            rust-analyzer
            pkg-config
            clippy
            rustfmt
          ];

          # Runtime dependencies
          buildInputs = with pkgs; [
            openssl
            sqlite
            just
          ];

          # Set environment variables
          shellHook = ''
            export RUST_BACKTRACE=1

            # Ensure bdk-cli is in PATH when in the devShell
            export PATH=$PATH:${self.packages.${system}.bdk-cli}/bin

            echo ""
            echo "Welcome to the bdk-cli development environment!"
            echo "Type 'just' to see available commands"
            echo ""
          '';
        };
      }
    );
}
