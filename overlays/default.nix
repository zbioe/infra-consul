{
  default = (_: prev: {
    # extend lib
    lib = prev.lib // import ../lib { inherit (prev) lib; };
    terraformWithPlugins = prev.terraform.withPlugins
      (p: [ p.null p.external p.libvirt p.google p.google-beta p.azurerm ]);
  });
}
