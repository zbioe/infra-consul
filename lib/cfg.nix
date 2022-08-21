{ lib }:
let
  inherit (builtins) length foldl' attrNames;
  inherit (lib) mkIf;
in {
  attrsMap = attrs: f:
    mkIf (length (attrNames attrs) > 0)
    (foldl' (a: b: a // b) { } (map f (attrNames attrs)));
}
