{...}: {
  imports = [
    # Plugins
    ./plugins/which-key.nix
    ./plugins/telescope.nix
    ./plugins/conform.nix
    ./plugins/lsp.nix
    ./plugins/nvim-cmp.nix
    ./plugins/mini.nix
    ./plugins/treesitter.nix

    ./plugins/kickstart/plugins/debug.nix
    # ./plugins/kickstart/plugins/lint.nix
    ./plugins/kickstart/plugins/neo-tree.nix

    ./plugins/custom/plugins/dap.nix
    ./plugins/custom/plugins/lazygit.nix
  ];

  programs.nixvim = {
    enable = true;

    # extraPackages = with pkgs; [
    # ];

    colorschemes = {
      gruvbox.enable = true;
      # nord.enable = true;
    };

    globals = {
      mapleader = ",";
      maplocalleader = ",";
      have_nerd_font = true;
    };

    clipboard = {
      providers = {
        wl-copy.enable = true; # For Wayland
        xsel.enable = true; # For X11
      };
      register = "unnamedplus";
    };

    # [[ Setting options ]]
    opts = {
      number = true; # Show line numbers
      mouse = "a"; # Enable mouse mode, can be useful for resizing splits for example!
      showmode = false; # Don't show the mode, since it's already in the statusline
      breakindent = true; # Enable break indent
      undofile = true; # Save undo history
      ignorecase = true; # Case-insensitive searching UNLESS \C or one or more capital letters in search term
      smartcase = true;
      signcolumn = "yes"; # Keep signcolumn on by default
      updatetime = 250; # Decrease update time
      timeoutlen = 300; # Decrease mapped sequence wait time. Displays which-key popup sooner
      expandtab = true; # All spaces, no tabs
      shiftwidth = 2;
      smartindent = true;
      tabstop = 2;
      softtabstop = 2;

      # Configure how new splits should be opened
      splitright = true;
      splitbelow = true;

      list = true; # Sets how neovim will display certain whitespace characters in the editor
      listchars.__raw = "{ tab = '» ', trail = '·', nbsp = '␣' }"; # NOTE: .__raw here means that this field is raw lua code
      inccommand = "split"; # Preview subsitutions live, as you type!
      cursorline = true; # Show which line your cursor is on
      scrolloff = 10; # Minimal number of screen lines to keep above and below the cursor
      hlsearch = true; # Set highlight on search, but clear on pressing <Esc> in normal mode

      swapfile = false; # Because way too annoying
    };

    # [[ Basic Keymaps ]]
    keymaps = [
      {
        # remap jj to <Esc> in insert mode
        mode = "i";
        key = "jj";
        action = "<Esc>";
      }
      {
        # remap semicolon to colon
        mode = "n";
        key = ";";
        action = ":";
      }
      # -- tab navigation
      {
        # vim.keymap.set('n', '<Leader>tt', ":tabnew<cr>")
        mode = "n";
        key = "<Leader>tt";
        action = "<cmd>tabnew<CR>";
      }
      {
        # vim.keymap.set('n', '<Leader>tn', ":tabnext<cr>")
        mode = "n";
        key = "<Leader>tn";
        action = "<cmd>tabnext<CR>";
      }
      {
        # vim.keymap.set('n', '<Leader>tp', ":tabprevious<cr>")
        mode = "n";
        key = "<Leader>tp";
        action = "<cmd>tabprevious<CR>";
      }
      {
        # vim.keymap.set('n', '<Leader>tc', ":tabclose<cr>")
        mode = "n";
        key = "<Leader>tc";
        action = "<cmd>tabclose<CR>";
      }
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
      }

      # Keybinds to make split navigation easier.
      #  Use CTRL+<hjkl> to switch between windows
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w><C-h>";
        options = {
          desc = "Move focus to the left window";
        };
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w><C-l>";
        options = {
          desc = "Move focus to the right window";
        };
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w><C-j>";
        options = {
          desc = "Move focus to the lower window";
        };
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w><C-k>";
        options = {
          desc = "Move focus to the upper window";
        };
      }
    ];

    # https://nix-community.github.io/nixvim/NeovimOptions/autoGroups/index.html
    autoGroups = {
      kickstart-highlight-yank = {
        clear = true;
      };
    };

    # [[ Basic Autocommands ]]
    #  See `:help lua-guide-autocommands`
    # https://nix-community.github.io/nixvim/NeovimOptions/autoCmd/index.html
    autoCmd = [
      # Highlight when yanking (copying) text
      #  Try it with `yap` in normal mode
      #  See `:help vim.highlight.on_yank()`
      {
        event = ["TextYankPost"];
        desc = "Highlight when yanking (copying) text";
        group = "kickstart-highlight-yank";
        callback.__raw = ''
          function()
            vim.highlight.on_yank()
          end
        '';
      }
    ];

    plugins = {
      web-devicons.enable = true;

      gitsigns.enable = true;

      nvim-autopairs.enable = true;

      # Detect tabstop and shiftwidth automatically
      # https://nix-community.github.io/nixvim/plugins/sleuth/index.html
      sleuth = {
        enable = true;
      };

      # "gc" to comment visual regions/lines
      # https://nix-community.github.io/nixvim/plugins/comment/index.html
      comment = {
        enable = true;
      };

      # Highlight todo, notes, etc in comments
      # https://nix-community.github.io/nixvim/plugins/todo-comments/index.html
      todo-comments = {
        enable = true;
        settings = {
          signs = true;
        };
      };

      # lualine.enable = true;
    };

    # The line beneath this is called `modeline`. See `:help modeline`
    # https://nix-community.github.io/nixvim/NeovimOptions/index.html?highlight=extraplugins#extraconfigluapost
    extraConfigLuaPost = ''
      -- vim: ts=2 sts=2 sw=2 et
    '';
  };
}
