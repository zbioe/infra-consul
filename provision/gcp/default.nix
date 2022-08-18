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
          project = mk' str gcp.project "project";
          region = mk' str gcp.region "region name";
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

      imagesModule = submodule ({ config, name, ... }: {
        options = {
          project = mk' str gcp.project "project";
          location = mk' str gcp.region "location";
          labels = mk' (attrsOf str) { name = name; } "labels";
          name = mk' str name "name of image";
          family = mk' str "nixos" "name of family";
          description = mk' str "description ${name}" "images description";
          source = mk' str
            "gs://nixos-images-gcp/nixos-image-21.05.4709.88579effa7e-x86_64-linux.raw.tar.z"
            "path for imgs or name of another volume";

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

        # images submodule
        images = mkOption {
          type = (attrsOf imagesModule);
          default = { };
          description = "image options";
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
    inherit (builtins) attrNames;
    inherit (lib) mkIf readFile;
    inherit (lib.strings) removeSuffix;
    inherit (pkgs.lib.cfg) attrsMap;
    gcp = config.provision.gcp;
    networks = gcp.networks;
    images = gcp.images;
    volumes = gcp.volumes;
    replicas = gcp.replicas;

    uuid = removeSuffix "\n" (readFile
      (pkgs.runCommand "gen-uuid" { buildInputs = [ pkgs.libuuid ]; }
        "uuidgen > $out"));
  in {
    terraform.required_providers =
      mkIf gcp.enable { google-beta.source = "hashicorp/google-beta"; };
    provider.google-beta = mkIf gcp.enable {
      project = gcp.project;
      region = gcp.region;
      zone = gcp.zone;
    };

    resource = mkIf gcp.enable {
      google_storage_bucket = attrsMap images (name: {
        ${name} = with images.${name}; {
          inherit project location labels;
          name = "${name}-${project}";
          # without it, will not destroy bucket with `destroy-gcp`
          # force_destroy = true;
        };
      });
      google_storage_bucket_object = attrsMap images (name: {
        ${name} = with images.${name}; {
          inherit name source;
          metadata = labels;
          bucket = config.resource.google_storage_bucket.${name}.name;
          # don't recreate it every time
          lifecycle = { ignore_changes = [ "source" ]; };
        };
      });

      google_compute_image = attrsMap images (name: {
        ${name} = with images.${name}; {
          inherit name project;
          family = name;
          source_image = "\${ google_storage_bucket_object.${name}.self_link }";
        };
      });

      # google_compute_instance = attrsMap replicas (name: {
      #   name = with replicas.${name}; {
      #     inherit name;
      #   };
      # });

      # google_compute_machine_image = foldl' (a: b: a // b) { } (map (name:
      #   let img = images.${name};
      #   in {
      #     ${name} = {
      #       inherit (img) project name description;
      #       # source_image = img.source;
      #       source_instance = img.source;
      #       provider = "google-beta";
      #     };
      #   }) (attrNames images));

      google_compute_network = attrsMap networks (name: {
        ${name} = with networks.${name}; {
          inherit project name mtu description routing_mode
            auto_create_subnetworks delete_default_routes_on_create;
        };
      });

      google_compute_subnetwork = attrsMap networks (name:
        let subnetworks = networks.${name}.subnetworks;
        in attrsMap subnetworks (sname: {
          ${sname} = let sub = subnetworks.${sname};
          in {
            inherit (sub) project region;
            name = sname;
            ip_cidr_range = sub.cidr_range;
            network = "\${ google_compute_network.${name}.id }";
            secondary_ip_range = map (v: {
              range_name = v.range_name;
              ip_cidr_range = v.cidr_range;
            }) sub.secondary_ranges;
          };
        }));

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
