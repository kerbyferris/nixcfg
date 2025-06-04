{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.davinci-resolve;
in {
  options.features.davinci-resolve.enable = mkEnableOption "enable davinci-resolve config";

  config = mkIf cfg.enable {
    boot.initrd.kernelModules = ["amdgpu "];
    # Enable openGL and install Rocm
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      # extraPackages = with pkgs.stable; [
      extraPackages = with pkgs; [
        intel-compute-runtime
        # rocmPackages_5.clr.icd
        rocmPackages.clr
        # rocmPackages.rocminfo
        # rocmPackages.rocm-runtime
        amdvlk
        driversi686Linux.amdvlk
      ];
    };

    # This is necesery because many programs hard-code the path to hip
    systemd.tmpfiles.rules = [
      # "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.stable.rocmPackages.clr}"
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];
    environment.variables = {
      # As of ROCm 4.5, AMD has disabled OpenCL on Polaris based cards. This is needed if you have a 500 series card.
      ROC_ENABLE_PRE_VEGA = "1";
    };
    environment.systemPackages = with pkgs; [
      davinci-resolve
      nvtopPackages.full
      clinfo
    ];
  };
}
