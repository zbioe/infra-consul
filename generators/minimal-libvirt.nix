{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/virtualisation/libvirtd.nix"
  ];
} // (import ./minimal-default.nix { inherit modulesPath; })
