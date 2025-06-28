{
  imports = [../common ./configuration.nix ./hardware-configuration.nix ../features];
  features = {
    video-editing.enable = true;
    freecad.enable = true;
    # amd-egpu.enable = true;
  };
}
