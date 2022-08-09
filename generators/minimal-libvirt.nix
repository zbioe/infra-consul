{ modulesPath, ... }: {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/virtualisation/libvirtd.nix"
    ./minimal-default.nix
  ];
  boot.loader.grub.devices = [ "/dev/sda" ];
}
