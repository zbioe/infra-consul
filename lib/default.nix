{ lib }:
{
  opt = import ./opt.nix { inherit lib; };
  cfg = import ./cfg.nix { inherit lib; };
} // lib
