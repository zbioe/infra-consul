{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/virtualisation/google-compute-config.nix"
  ];
} // (import ./minimal-default.nix { inherit modulesPath; })
