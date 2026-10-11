{pkgs, ...}: {
  imports = [../common ./configuration.nix ./hardware-configuration.nix ../features];
  features = {
    video-editing.enable = true;
    freecad.enable = false;
    amd-egpu.enable = true;
    sops.enable = true;
  };

  # ArtCraft apps (PhotoCraft, VectorCraft, DesignCraft, LightCraft,
  # FilmCraft, EffectCraft, PdfCraft) from the official release AppImages,
  # mirrored by the artcraft-nix flake. linkFonts exposes the system fonts at
  # /usr/share/fonts, which is the only place the apps' text tools look.
  #
  # apps = [] because the packages come from our own overlay instead
  # (pkgs.artcraftX11, see overlays/default.nix): those are the same apps
  # re-wrapped to drop WAYLAND_DISPLAY so winit uses XWayland, which is the
  # only backend where native file drag-and-drop works. Installing both sets
  # would collide on the same bin/ names.
  programs.artcraft = {
    enable = true;
    apps = [];
    linkFonts = true;
  };
  environment.systemPackages = builtins.attrValues pkgs.artcraftX11;
}
