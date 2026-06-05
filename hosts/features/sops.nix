{
  config,
  lib,
  ...
}: let
  cfg = config.features.sops;
in {
  options.features.sops = {
    enable = lib.mkEnableOption "SOPS secret management via sops-nix";
  };

  config = lib.mkIf cfg.enable {
    # Derive age identity from the SSH host key for boot-time decryption
    sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  };
}
