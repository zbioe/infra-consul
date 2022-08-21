{ lib }:
let
  inherit (builtins) length foldl' attrNames;
  inherit (lib) mkIf;
  inherit (lib.lists) imap0;
in {
  # f = key: value: ... ;
  attrsMap = attrs: f:
    mkIf (length (attrNames attrs) > 0)
    (foldl' (a: b: a // b) { } (map f (attrNames attrs)));

  # f = index: value: ... ;
  listMap = attrs: f:
    mkIf (length (attrNames attrs) > 0) (imap0 f (attrNames attrs));

}
