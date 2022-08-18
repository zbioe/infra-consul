{ modulesPath, ... }: {
  imports =
    [ "${modulesPath}/virtualisation/azure-config.nix" ./minimal-default.nix ];
}
