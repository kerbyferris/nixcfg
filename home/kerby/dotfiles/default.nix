{ inputs, ... }: {
  home.file.".config/nvim" = {
    source = "${inputs.dotfiles}/tree/main/nvim";
    recursive = true;
  };
}
