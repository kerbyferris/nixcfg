{...}: {
  programs.nixvim.plugins.lazygit = {
    enable = true;
  };
  programs.nixvim.keymaps = [
    {
      key = "<leader>lg";
      action = "<cmd>LazyGit<cr>";
      options = {
        desc = "Open LazyGit";
      };
    }
  ];
}
