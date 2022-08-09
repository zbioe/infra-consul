{ modulesPath, ... }: {
  imports = [
    "${modulesPath}/virtualisation/google-compute-config.nix"
    ./minimal-default.nix
  ];
}
