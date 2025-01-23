{ inputs, ... }: {
  home.file.".config/nvim" = {
    source = "${inputs.dotfiles}/nvim";
    recursive = true;
  };
  home.file.".config/hypr" = {
    source = "${inputs.dotfiles}/hypr";
    recursive = true;
  };
  home.file.".config/wayland" = {
    source = "${inputs.dotfiles}/wayland";
    recursive = true;
  };
}
