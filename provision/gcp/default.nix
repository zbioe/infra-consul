{ config, pkgs, ... }:
let inherit (pkgs) lib;
in {
  options = with lib.types;
    let
      inherit (lib.opt) mk' mkBool';
      inherit (lib) mkOption;
      gcp = config.provision.gcp;
      networksModule = submodule ({ config, name, ... }: {
        options = {
          project = mk' str gcp.project "project";
          name = mk' str name "name of network";
          mtu = mk' int 1460 "Maximum Transmission Unit in bytes";
          description = mk' str "description of this resource" "";
          routing_mode = mk' (enum [ "GLOBAL" "REGIONAL" ]) "REGIONAL"
            "The network-wide routing mode to use.";
          auto_create_subnetworks = mkBool' false
            "create a subnet for each region automatically across the 10.128.0.0/9 address range";
          delete_default_routes_on_create = mkBool' false
            "If set to true, default routes (0.0.0.0/0) will be deleted immediately after network creation.";
          subnetworks = mkOption {
            type = (attrsOf subnetworksModule);
            default = { };
            description = "subnetwork options";
          };
        };
      });

      subnetworksModule = submodule ({ config, name, ... }: {
        options = {
          name = mk' str name "name of subnetwork";
          cidr_range = mk' str "10.62.0.0/16" "cidr range network";
          network = mk' str config.name "network name";
          description = mk' str "subnetwork ${name}" "subnetwork description";
          secondary_ranges = mk' (listOf (submodule {
            options = {
              range_name = mk' str name "name-of-subnetwork";
              cidr_range = mk' str name "10.21.0.0/16";
            };
          })) [ ] "secondary ip range list";
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
          machine_type = mk' str "e2-micro" "type of machine";
        };
      });

    in {
      provision.gcp = {
        enable = mkBool' false "enable gcp provision";
        project = mk' str "consul" "project name";
        region = mk' str "us-east1" "region name";
        zone = mk' str "us-east1-c"
          "zone name. expected to be in same region setted, if not it takes priority over region";
        # network submodule
        networks = mkOption {
          type = (attrsOf networksModule);
          default = { };
          description = "network options";
        };

        # subnetwork submodule
        subnetworks = mkOption {
          type = (attrsOf subnetworksModule);
          default = { };
          description = "subnetwork options";
        };

        # # volumes submodule
        # volumes = mkOption {
        #   type = (attrsOf volumesModule);
        #   default = { };
        #   description = "volumes options";
        # };
        # # replica submodule
        replicas = mkOption {
          type = (attrsOf replicasModule);
          default = { };
          description = "replicas options";
        };
      };
    };
  config = let
    gcp = config.provision.gcp;
    networks = gcp.networks;
    volumes = gcp.volumes;
    replicas = gcp.replicas;
    inherit (builtins) attrNames foldl';
    inherit (lib) mkIf;
  in {
    terraform.required_providers =
      mkIf gcp.enable { gooogle.source = "hashicorp/google"; };
    provider.google = mkIf gcp.enable {
      project = gcp.project;
      region = gcp.region;
      zone = gcp.zone;
    };
    resource = mkIf gcp.enable {
      google_compute_network = foldl' (a: b: a // b) { } (map (name: {
        ${name} = with networks.${name}; {
          inherit project name mtu description routing_mode
            auto_create_subnetworks delete_default_routes_on_create;
        };
      }) (attrNames networks));
      # google_compute_subnetwork_old = foldl' (a: b: a // b) { } (map (name:
      #   let subnetworks = networks.${name};
      #   in foldl' (a: b: a // b) { } (map (sname: {
      #     ${sname} = with subnetworks.${sname}; {
      #       name = sname;
      #       id_cidr_range = cidr_range;
      #       network = "\${ google_compute_network.${name}.id }";
      #       # secondary_ip_range = secondary_ranges;
      #     };
      #   }) (attrNames subnetworks))) (attrNames networks));

      google_compute_subnetwork = foldl' (a: b: a // b) { } (map (name:
        let subnetworks = networks.${name}.subnetworks;
        in foldl' (a: b: a // b) { } (map (sname: {
          ${sname} = let sub = subnetworks.${sname};
          in {
            name = sname;
            ip_cidr_range = sub.cidr_range;
            network = "\${ google_compute_network.${name}.id }";
            secondary_ip_range = map (v: {
              range_name = v.range_name;
              ip_cidr_range = v.cidr_range;
            }) sub.secondary_ranges;
          };
        }) (attrNames subnetworks))) (attrNames networks));
      # google_compute_instance = foldl' (a: b: a // b) { } (map (name: {
      #   ${name} = {
      #     inherit name;
      #     machine_type = replicas.${name}.machine_type;
      #     netowrk_interface = { network = "default"; };
      #   };
      # }) (attrNames replicas));
    };

    # libvirt_network = foldl' (a: b: a // b) { } (map (name: {
    #   ${name} = {
    #     inherit (networks.${name}) name;
    #     #
    #     mode = networks.${name}.mode;
    #     dhcp = { enabled = networks.${name}.dhcp.enable; };
    #     dns = { enabled = networks.${name}.dns.enable; };
    #     domain = networks.${name}.domain;
    #     addresses = networks.${name}.addresses;
    #   };
    # }) (attrNames networks));

    #     libvirt_volume = foldl' (a: b: a // b) { } (map (name: {
    #       ${name} = let
    #         vsource = volumes.${name}.source;
    #         vname = volumes.${name}.name;
    #       in {
    #         name = vname;
    #         source = if builtins.isString volumes.${name}.source then
    #           "\${ libvirt_volume.${vsource}.id }"
    #         else
    #           toString vsource;
    #       };
    #     }) (attrNames volumes));

    #     libvirt_domain = foldl' (a: b: a // b) { } (map (name: {
    #       ${name} = let repl = replicas.${name};
    #       in {
    #         inherit name;
    #         network_interface = map (vname:
    #           let
    #             vnet = repl.interfaces.${vname};
    #             domain = networks.${vname}.domain;
    #           in {
    #             network_id = "\${ libvirt_network.${vname}.id }";
    #             hostname = name + "." + domain;
    #             addresses = vnet.addresses;
    #             mac = vnet.mac;
    #             wait_for_lease = vnet.wait_for_lease;
    #           }) (attrNames repl.interfaces);
    #         disk = (map (dname: {
    #           volume_id = "\${ libvirt_volume.${dname}.id }";
    #           scsi = "true";
    #           url = "";
    #           wwn = "";
    #           block_device = "";
    #           file = "";
    #         }) repl.disks);
    #       };
    #     }) (attrNames replicas));
    #   };
    #   output = foldl' (a: b: a // b) { } (map (name:
    #     let
    #       inherit (builtins) head;
    #       repl = replicas.${name};
    #       addrs = map (interface: (head repl.interfaces.${interface}.addresses))
    #         (attrNames repl.interfaces);
    #     in {
    #       ${name} = {
    #         # first ip of first interface for each vm
    #         value = {
    #           inherit name;
    #           domain = name;
    #           ip = {
    #             pub = head addrs;
    #             priv = head addrs;
    #           };
    #         };
    #       };
    #     }) (attrNames replicas));
  };
}
