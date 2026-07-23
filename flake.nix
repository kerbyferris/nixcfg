{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

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
        inherit (pkgs) vidplayvst bitwig-fhs bitwig-debug-shell bitwig-connect-control-panel pi-commandcode-provider;
      }
    );

    overlays = import ./overlays {inherit inputs;};

    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/nixos
          determinate.nixosModules.default
          stylix.nixosModules.stylix
          home-manager.nixosModules.default
          {nixpkgs.overlays = [outputs.overlays.additions outputs.overlays.stable-packages outputs.overlays.modifications inputs.llm-agents.overlays.shared-nixpkgs];}
          sops-nix.nixosModules.sops
        ];
      };
    };
  };
}
