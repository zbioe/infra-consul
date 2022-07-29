{ pkgs ? import ../../nixpkgs { }, nixt, ... }:

nixt.mkSuites {
  "foo suite" = { "foo is foo" = "foo" == "foo"; };
  "bar suite" = { "bar is bar" = "bar" == "baz"; };
}
