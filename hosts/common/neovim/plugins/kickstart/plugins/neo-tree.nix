{
  # Neo-tree is a Neovim plugin to browse the file system
  # https://nix-community.github.io/nixvim/plugins/neo-tree/index.html?highlight=neo-tree#pluginsneo-treepackage
  programs.nixvim.plugins.neo-tree = {
    enable = true;

    settings = {
      window = {
        mappings = {
          o = "open";
        };
        width = 30;
      };
      extraOptions = {
        filesystem = {
          filtered_items = {
            visible = true;
          };
        };
      };
    };
  };

  # https://nix-community.github.io/nixvim/keymaps/index.html
  programs.nixvim.keymaps = [
    {
      key = "<leader>nt";
      action = "<cmd>Neotree toggle reveal<cr>";
      options = {
        desc = "NeoTree toggle reveal";
      };
    }
  ];
}
