{
  # Neo-tree is a Neovim plugin to browse the file system
  # https://nix-community.github.io/nixvim/plugins/neo-tree/index.html?highlight=neo-tree#pluginsneo-treepackage
  plugins.neo-tree = {
    enable = true;

    filesystem = {
      window = {
        mappings = {
          "\\" = "close_window";
          "o" = "open";
        };
      };
    };
  };

  # https://nix-community.github.io/nixvim/keymaps/index.html
  keymaps = [
    {
      key = "<leader>nt";
      action = "<cmd>Neotree toggle reveal<cr>";
      options = {
        desc = "NeoTree toggle reveal";
      };
    }
  ];
}
