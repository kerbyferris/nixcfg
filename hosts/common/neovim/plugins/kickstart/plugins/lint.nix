{pkgs, ...}: {
  programs.nixvim.extraPackages = with pkgs; [
    nodePackages_latest.coc-markdownlint
    nix
    vale
    nodePackages.jsonlint
    tflint
  ];
  # Linting
  # https://nix-community.github.io/nixvim/plugins/lint/index.html
  programs.nixvim.plugins.lint = {
    enable = true;

    # NOTE: Enabling these will cause errors unless these tools are installed
    lintersByFt = {
      nix = ["nix"];
      markdown = [
        "markdownlint"
        "vale"
      ];
      #clojure = ["clj-kondo"];
      #dockerfile = ["hadolint"];
      #inko = ["inko"];
      #janet = ["janet"];
      json = ["jsonlint"];
      rst = ["vale"];
      #ruby = ["ruby"];
      terraform = ["tflint"];
      #text = ["vale"];
    };

    # Create autocommand which carries out the actual linting
    # on the specified events.
    autoCmd = {
      callback.__raw = ''
        function()
          require('lint').try_lint()
        end
      '';
      group = "lint";
      event = [
        "BufEnter"
        "BufWritePost"
        "InsertLeave"
      ];
    };
  };

  # https://nix-community.github.io/nixvim/NeovimOptions/autoGroups/index.html
  programs.nixvim.autoGroups = {
    lint = {
      clear = true;
    };
  };
}
