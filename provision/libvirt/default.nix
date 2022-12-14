{ config, pkgs, ... }:
let inherit (pkgs) lib;
in {
  options = with lib.types;
    let
      inherit (lib.opt) mk' mkBool';
      inherit (lib) mkOption;
      networksModule = submodule ({ config, name, ... }: {
        options = {
          name = mk' str name "name of network";
          mode = mk' str "nat" "mode of network";
          domain = mk' str "vm.local" "domain";
          addresses = mk' (listOf str) [ "10.0.62.0/24" ] "list of CIDR's";
          dhcp = mkOption {
            description = "dhcp options";
            type = (submodule {
              options = { enable = mkBool' false "enable dhcp"; };
            });
            default = { };
          };
          dns = mkOption {
            description = "dns options";
            type = (submodule {
              options = { enable = mkBool' false "enable dns"; };
            });
            default = { };
          };
        };
      });

      volumesModule = submodule ({ config, name, ... }: {
        options = {
          name = mk' str name "name of volume";
          source = mk' (oneOf [ str path ]) "nixos"
            "path for imgs or name of another volume";
        };
      });

      replicasModule = submodule ({ config, name, ... }: {
        options = {
          name = mk' str name "name of replica";
          disks = mk' (listOf str) [ ] "list of disks";
          interfaces = mkOption {
            description = "setup interfaces";
            type = (attrsOf (submodule ({ config, vname, ... }: {
              options = let
                domain = config.provision.libvirt.networks.${vname}.domain;
                hostname = "${name}.${domain}";
              in {
                name = mk' str vname "interface name";
                hostname = mk' str hostname "hostname";
                addresses = mk' (listOf str) [ ] "list of ip addresses";
                mac = mk' str "" "mac acddress";
                wait_for_lease = mkBool' true "wait for lease";
              };
            })));
            default = { };
          };
        };
      });

    in {
      provision.libvirt = {
        enable = mkBool' false "enable libvirt provision";
        uri = mk' str "qemu:///system" "qemu uri";
        # network submodule
        networks = mkOption {
          type = (attrsOf networksModule);
          default = { };
          description = "network options";
        };
        # volumes submodule
        volumes = mkOption {
          type = (attrsOf volumesModule);
          default = { };
          description = "volumes options";
        };
        # replica submodule
        replicas = mkOption {
          type = (attrsOf replicasModule);
          default = { };
          description = "volumes options";
        };
      };
    };
  config = let
    virt = config.provision.libvirt;
    networks = virt.networks;
    volumes = virt.volumes;
    replicas = virt.replicas;
    inherit (builtins) attrNames foldl';
    inherit (lib) mkIf;
  in {
    terraform.required_providers =
      mkIf virt.enable { libvirt.source = "dmacvicar/libvirt"; };
    provider.libvirt = mkIf virt.enable { uri = virt.uri; };
    resource = mkIf virt.enable {
      libvirt_network = foldl' (a: b: a // b) { } (map (name: {
        ${name} = {
          inherit (networks.${name}) name;
          #
          mode = networks.${name}.mode;
          dhcp = { enabled = networks.${name}.dhcp.enable; };
          dns = { enabled = networks.${name}.dns.enable; };
          domain = networks.${name}.domain;
          addresses = networks.${name}.addresses;
        };
      }) (attrNames networks));

      libvirt_volume = foldl' (a: b: a // b) { } (map (name: {
        ${name} = let
          vsource = volumes.${name}.source;
          vname = volumes.${name}.name;
        in {
          name = vname;
          source = if builtins.isString volumes.${name}.source then
            "\${ libvirt_volume.${vsource}.id }"
          else
            toString vsource;
        };
      }) (attrNames volumes));

      libvirt_domain = foldl' (a: b: a // b) { } (map (name: {
        ${name} = let repl = replicas.${name};
        in {
          inherit name;
          network_interface = map (vname:
            let
              vnet = repl.interfaces.${vname};
              domain = networks.${vname}.domain;
            in {
              network_id = "\${ libvirt_network.${vname}.id }";
              hostname = name + "." + domain;
              addresses = vnet.addresses;
              mac = vnet.mac;
              wait_for_lease = vnet.wait_for_lease;
            }) (attrNames repl.interfaces);
          disk = (map (dname: {
            volume_id = "\${ libvirt_volume.${dname}.id }";
            scsi = "true";
            url = "";
            wwn = "";
            block_device = "";
            file = "";
          }) repl.disks);
        };
      }) (attrNames replicas));
    };
    output = mkIf virt.enable (foldl' (a: b: a // b) { } (map (name:
      let inherit (builtins) head;
      in {
        # first ip of first interface for each vm
        ${name} = {
          value = {
            inherit name;
            ip.pub =
              "\${ libvirt_domain.${name}.network_interface.0.addresses.0 }";
          };
        };
      }) (attrNames replicas)));
  };
}
