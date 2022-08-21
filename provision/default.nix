{ config, lib, pkgs, ... }:

{
  imports = [ ./libvirt ./gcp ./azure ];
}
