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
        # networks = mkOption {
        #   type = (attrsOf networksModule);
        #   default = { };
        #   description = "network options";
        # };
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
      google_compute_instance = foldl' (a: b: a // b) { } (map (name: {
        ${name} = {
          inherit name;
          machine_type = replicas.${name}.machine_type;
          netowrk_interface = { network = "default"; };
        };
      }) (attrNames replicas));
    };
    #     libvirt_network = foldl' (a: b: a // b) { } (map (name: {
    #       ${name} = {
    #         inherit (networks.${name}) name;
    #         #
    #         mode = networks.${name}.mode;
    #         dhcp = { enabled = networks.${name}.dhcp.enable; };
    #         dns = { enabled = networks.${name}.dns.enable; };
    #         domain = networks.${name}.domain;
    #         addresses = networks.${name}.addresses;
    #       };
    #     }) (attrNames networks));

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
