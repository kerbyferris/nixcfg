#!/usr/bin/env bash
# Export compiled nixvim config for use on Termux/Android.
#
# The nixvim init.lua lives at a Nix store path that changes every rebuild.
# This script extracts it from the nvim wrapper and copies it to a folder
# you can sync to Termux via syncthing (one-time baseline, not continuous).
#
# On Termux: copy the three files into ~/.config/nvim/ and own them from there.
#
# Usage: bin/export-nvim-config.sh [output-dir]
# Default output dir: ~/Sync/nvim

set -euo pipefail

SYNC_DIR="${1:-$HOME/Sync/nvim}"
mkdir -p "$SYNC_DIR"

# Extract compiled init.lua from the nvim wrapper's VIMINIT export
NVIM_BIN=$(readlink -f "/run/current-system/sw/bin/nvim" 2>/dev/null || readlink -f "$(command -v nvim)" 2>/dev/null || echo "")
if [ -z "$NVIM_BIN" ] || [ ! -f "$NVIM_BIN" ]; then
  echo "error: could not find nvim binary" >&2
  exit 1
fi

INIT_LUA=$(grep -oP "/nix/store/[^'\\\\]+-init\.lua" "$NVIM_BIN" 2>/dev/null || echo "")
if [ -z "$INIT_LUA" ] || [ ! -f "$INIT_LUA" ]; then
  echo "error: could not extract init.lua path from nvim wrapper" >&2
  exit 1
fi

rm -f "$SYNC_DIR/init.lua" 2>/dev/null || chmod u+w "$SYNC_DIR/init.lua" 2>/dev/null || true
cp "$INIT_LUA" "$SYNC_DIR/init.lua"
chmod u+w "$SYNC_DIR/init.lua"
echo "exported init.lua ($(wc -l < "$SYNC_DIR/init.lua") lines)"

# lazy.nvim plugin spec — maps nixvim plugins to GitHub repos for Termux
cat > "$SYNC_DIR/lazy-spec.lua" << 'LAZY_EOF'
return {
  { "ellisonleao/gruvbox.nvim", lazy = false },
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" }, lazy = false },
  { "nvim-telescope/telescope-fzf-native.nvim", build = "make", lazy = false },
  { "nvim-telescope/telescope-ui-select.nvim", lazy = false },
  { "hrsh7th/nvim-cmp", lazy = false },
  { "hrsh7th/cmp-nvim-lsp", lazy = false },
  { "hrsh7th/cmp-path", lazy = false },
  { "saadparwaiz1/cmp_luasnip", lazy = false },
  { "L3MON4D3/LuaSnip", lazy = false },
  { "neovim/nvim-lspconfig", lazy = false },
  { "folke/neodev.nvim", lazy = false },
  { "nvimdev/lspsaga.nvim", lazy = false },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", lazy = false },
  { "folke/which-key.nvim", lazy = false },
  { "folke/trouble.nvim", lazy = false },
  { "folke/todo-comments.nvim", lazy = false },
  { "folke/fidget.nvim", lazy = false },
  { "nvim-tree/nvim-web-devicons", lazy = false },
  { "nvim-neo-tree/neo-tree.nvim", dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" }, lazy = false },
  { "echasnovski/mini.nvim", lazy = false },
  { "lewis6991/gitsigns.nvim", lazy = false },
  { "kdheepak/lazygit.nvim", lazy = false },
  { "mfussenegger/nvim-dap", lazy = false },
  { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, lazy = false },
  { "leoluz/nvim-dap-go", lazy = false },
  { "stevearc/conform.nvim", lazy = false },
  { "numToStr/Comment.nvim", lazy = false },
  { "windwp/nvim-autopairs", lazy = false },
  { "tpope/vim-sleuth", lazy = false },
}
LAZY_EOF
echo "exported lazy-spec.lua ($(grep -c 'lazy = false' "$SYNC_DIR/lazy-spec.lua") plugins)"

# Termux bootstrap — loads plugins via lazy.nvim, then sources the nixvim init.lua
cat > "$SYNC_DIR/termux-init.lua" << 'TERMUX_EOF'
-- Termux neovim bootstrap
-- Loads plugins via lazy.nvim, then sources the nixvim-compiled init.lua.
--
-- Usage: nvim -u ~/Sync/nvim/termux-init.lua
-- Or:   copy this to ~/.config/nvim/init.lua and adjust sync_dir below

local sync_dir = vim.fn.expand("~/Sync/nvim")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load plugin spec
local ok, spec = pcall(dofile, sync_dir .. "/lazy-spec.lua")
if not ok then
  vim.notify("Could not load lazy-spec.lua from " .. sync_dir, vim.log.levels.ERROR)
  return
end

require("lazy").setup(spec, {
  install = { missing = true },
  root = vim.fn.stdpath("data") .. "/lazy",
})

-- After plugins are loaded, source the nixvim-compiled init.lua
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  once = true,
  callback = function()
    local ok, err = pcall(dofile, sync_dir .. "/init.lua")
    if not ok then
      vim.notify("nixvim init.lua error: " .. tostring(err), vim.log.levels.WARN)
    end
  end,
})
TERMUX_EOF
echo "exported termux-init.lua"

echo ""
echo "Done. Files in $SYNC_DIR:"
echo "  init.lua         — nixvim-compiled config (keymaps, options, plugin setups)"
echo "  lazy-spec.lua    — plugin list for lazy.nvim"
echo "  termux-init.lua  — bootstrap script for Termux"
echo ""
echo "Next steps:"
echo "  1. Share $SYNC_DIR to your Android device (syncthing, scp, etc.)"
echo "  2. On Termux: pkg install neovim git clang"
echo "  3. Copy files to ~/.config/nvim/ and customize freely"
