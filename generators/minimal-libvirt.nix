{ modulesPath, ... }:
let
  ssh-keys = import ../ssh-keys.nix;
  username = "main";
  password = "alface";
in {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/virtualisation/libvirtd.nix"
  ];
  # Enable the OpenSSH daemon
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;

  users = {
    mutableUsers = false;
    users = {
      root = {
        openssh.authorizedKeys.keys = ssh-keys;
        initialPassword = password;
      };
      ${username} = {
        isNormalUser = true;
        home = "/home/${username}";
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = ssh-keys;
        initialPassword = password;
      };
    };
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" ];
  system.stateVersion = "22.11";
}
