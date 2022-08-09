{ config, lib, pkgs, ... }: {
  provision.libvirt = {
    networks = {
      n1 = {
        mode = "nat";
        domain = "n1.local";
        addresses = [ "10.0.62.0/24" ];
        dhcp.enable = true;
        dns.enable = true;
      };
    };
    volumes = {
      nixos = { source = qcow/nixos.qcow2; };
      c1v1 = { source = "nixos"; };
      c1v2 = { source = "nixos"; };
      c1v3 = { source = "nixos"; };
      c2v1 = { source = "nixos"; };
      c2v2 = { source = "nixos"; };
      c2v3 = { source = "nixos"; };
    };
    replicas = {
      c1r1 = {
        interfaces = { n1.addresses = [ "10.0.62.11" ]; };
        disks = [ "c1v1" ];
      };
      c1r2 = {
        interfaces = { n1.addresses = [ "10.0.62.12" ]; };
        disks = [ "c1v2" ];
      };
      c1r3 = {
        interfaces = { n1.addresses = [ "10.0.62.13" ]; };
        disks = [ "c1v3" ];
      };
      c2r1 = {
        interfaces = { n1.addresses = [ "10.0.62.14" ]; };
        disks = [ "c2v1" ];
      };
      c2r2 = {
        interfaces = { n1.addresses = [ "10.0.62.15" ]; };
        disks = [ "c2v2" ];
      };
      c2r3 = {
        interfaces = { n1.addresses = [ "10.0.62.16" ]; };
        disks = [ "c2v3" ];
      };
    };
  };
}
