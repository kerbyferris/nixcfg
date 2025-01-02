{ inputs, ... }: {
  home.file.".config/nvim" = {
    source = "${inputs.dotfiles}";
    recursive = true;
  };
}
