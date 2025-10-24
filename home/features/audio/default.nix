{pkgs, ...}: {
  imports = [
    ./pipewire/pipewire.conf.d/10-virtual-sinks.conf
  ];
  home.packages = with pkgs; [
    bitwig-studio
    vcv-rack
  ];
}
