{
  default = (_: prev: {
    # extend lib
    lib = prev.lib // import ../lib { inherit (prev) lib pkgs; };
    terraformWithPlugins =
      prev.terraform.withPlugins (p: [ p.libvirt p.google p.azurerm ]);
  });
}
