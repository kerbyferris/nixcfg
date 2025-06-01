{
  description = ''
    Good example starter configs:

    https://github.com/Misterio77/nix-starter-configs
    https://github.com/Misterio77/nix-config
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    # nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    # nixpkgs-stable.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

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
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # flake-parts.url = "github:hercules-ci/flake-parts";
    nixvim = {
      # url = "github:kerbyferris/kickstart.nixvim";
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
  };

  outputs = {
    self,
    determinate,
    home-manager,
    nixpkgs,
    stylix,
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
    packages =
      forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    overlays = import ./overlays {inherit inputs;};
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/nixos
          determinate.nixosModules.default
          stylix.nixosModules.stylix
        ];
      };
    };
    homeConfigurations = {
      "kerby@nixos" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          ./home/kerby/nixos.nix
        ];
      };
    };
  };
}
