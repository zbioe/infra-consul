{
  default = (_: prev: {
    # extend lib
    lib = prev.lib // import ../lib { inherit (prev) lib; };
    terraformWithPlugins =
      prev.terraform.withPlugins (p: [ p.libvirt p.google p.azurerm ]);
  });
}
