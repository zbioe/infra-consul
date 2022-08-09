{ modulesPath, ... }:
let
  ssh-keys = import ./ssh-keys.nix;
  username = "main";
  password = "alface";
in {
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.grub.enable = true;
  boot.loader.timeout = 0;

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
