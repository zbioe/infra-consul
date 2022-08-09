{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/virtualisation/libvirtd.nix"
  ];
  boot.loader.grub.devices = [ "/dev/sda" ];
} // (import ./minimal-default.nix { inherit modulesPath; })
