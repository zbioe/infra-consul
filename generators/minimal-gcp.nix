{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/google-compute-config.nix" ];
} // (import ./minimal-default.nix { inherit modulesPath; })
