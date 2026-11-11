{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    # Rev-frozen nixpkgs for packages that are never in the binary cache and are
    # expensive to build. `bambu-studio` is the only such package so far: it is
    # unfree (it dlopens Bambu's proprietary networking library), and
    # cache.nixos.org does not distribute unfree packages, so it is always built
    # from source here — ~3 h on this laptop, including its own wxGTK/WebKit and
    # opencv/opencascade/oneTBB dependencies. The nixpkgs revision is part of
    # every derivation hash, so ANY nixpkgs bump re-keys it and pays that cost
    # again. A full 40-char rev in the URL is immutable: `nix flake update`
    # cannot move it, so updating the rest of the system no longer rebuilds it.
    # To take a new version, replace the rev below (with the one your current
    # nixpkgs uses, or any rev that has the version you want) and re-lock.
    nixpkgs-pin.url = "github:nixos/nixpkgs/f4a03c008967841f2a0b3cb7c436fc6fc31671f6";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # flake-parts.url = "github:hercules-ci/flake-parts";
    nixvim.url = "github:nix-community/nixvim";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
    # tagstudio.url = "github:TagStudioDev/TagStudio";
    hyprdynamicmonitors.url = "github:fiffeek/hyprdynamicmonitors";
    # pi-flake.url = "github:ChauDucToan/pi-flake";
    llm-agents.url = "github:numtide/llm-agents.nix";
    artcraft = {
      url = "github:ipeglin/artcraft-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    determinate,
    home-manager,
    nixpkgs,
    stylix,
    hyprdynamicmonitors,
    sops-nix,
    llm-agents,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (
      system: let
        # Create a nixpkgs instance for the given system and apply our overlay to it.
        pkgs = import nixpkgs {
          localSystem.system = system;
          overlays = [
            self.overlays.additions
          ];
          config.allowUnfree = true;
        };
      in {
        inherit (pkgs) vidplayvst bitwig-fhs bitwig-debug-shell bitwig-connect-control-panel pi-commandcode-provider immich-go;
      }
    );

    overlays = import ./overlays {inherit inputs;};

    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/nixos
          inputs.artcraft.nixosModules.default
          determinate.nixosModules.default
          stylix.nixosModules.stylix
          home-manager.nixosModules.default
          {nixpkgs.overlays = [outputs.overlays.additions outputs.overlays.stable-packages outputs.overlays.pinned-packages outputs.overlays.artcraftX11 outputs.overlays.modifications inputs.llm-agents.overlays.shared-nixpkgs];}
          sops-nix.nixosModules.sops
        ];
      };
    };
  };
}
