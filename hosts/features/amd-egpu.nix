{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.amd-egpu;
in {
  options.features.amd-egpu.enable = mkEnableOption "enable amd-egpu";

  config = mkIf cfg.enable {
    boot.initrd.kernelModules = ["amdgpu"];
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.amdgpu.opencl.enable = true;

    # This is necesery because many programs hard-code the path to hip
    systemd.tmpfiles.rules = [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];
    environment.systemPackages = with pkgs; [
      # nvtopPackages.full
      amdgpu_top
    ];
  };
}
