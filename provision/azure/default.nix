{ config, pkgs, ... }:
let inherit (pkgs) lib;
in {
  options = with lib.types;
    let
      inherit (lib.opt) mk' mkBool';
      inherit (lib) mkOption;
      azure = config.provision.azure;
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
          zone = mk' str gcp.zone "name of image";
          family = mk' str "nixos" "name of family";
          description = mk' str "description ${name}" "images description";
          source = mk' str
            "gs://nixos-images-gcp/nixos-image-21.05.4709.88579effa7e-x86_64-linux.raw.tar.z"
            "path for imgs or name of another volume";

        };
      });

      replicasModule = submodule ({ config, name, ... }: {
        options = {
          project = mk' str gcp.project "project";
          name = mk' str name "name of replica";
          machine_type = mk' str "e2-micro" "type of machine";
          tags = mk' (listOf str) [ name ] "tags";
          image = mk' str "nixos" "image used by instances";
          zone = mk' str azure.zone "name of image";
          size = mk' int 20 "size of vm";
          network = mk' str "default" "network interface used";
          subnetwork = mk' str "n1" "subnetwork interface used";
        };
      });

    in {
      provision.azure = {
        enable = mkBool' false "enable azure provision";
        project = mk' str "consul" "project name";
        region = mk' str "us-east1" "region name";
        zone = mk' str "us-east1-c"
          "zone name. expected to be in same region setted, if not it takes priority over region";
        domain = mk' str "d" "domain";
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

        # replica submodule
        replicas = mkOption {
          type = (attrsOf replicasModule);
          default = { };
          description = "replicas options";
        };
      };
    };
  config = let
    inherit (builtins) attrNames;
    inherit (lib) mkIf readFile assertMsg;
    inherit (lib.strings) removeSuffix;
    inherit (pkgs.lib.cfg) attrsMap;
    azure = config.provision.azure;
    networks = azure.networks;
    images = azure.images;
    replicas = azure.replicas;

  in {
    terraform.required_providers =
      mkIf azure.enable { azurerm.source = "hashicorp/azurerm"; };
    provider.azurerm = mkIf azure.enable {
      project = azure.project;
      region = azure.region;
      zone = azure.zone;
    };

    resource = mkIf gcp.enable {
      google_storage_bucket = attrsMap images (name: {
        ${name} = with images.${name}; {
          inherit project location labels;
          name = "${name}-${project}";
          # without it, will not destroy bucket with `destroy-gcp`
          force_destroy = true;
        };
      });
      google_storage_bucket_object = attrsMap images (name: {
        ${name} = with images.${name}; {
          inherit source;
          name = "${name}.tar.gz";
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
          raw_disk = {
            source = "\${ google_storage_bucket_object.${name}.self_link }";
            container_type = "TAR";
          };
        };
      });

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

      google_compute_instance = attrsMap replicas (name: {
        ${name} = with replicas.${name}; {
          inherit name machine_type tags project zone;
          network_interface = {
            network = "\${ google_compute_network.${network}.self_link }";
            subnetwork =
              "\${ google_compute_subnetwork.${subnetwork}.self_link }";
            access_config = { };
          };
          boot_disk = {
            initialize_params = {
              inherit size;
              image = "\${ google_compute_image.${image}.self_link }";
            };
          };
        };
      });

    };
    output = attrsMap replicas (name:
      let
        inherit (builtins) head;
        repl = replicas.${name};
        pub =
          "\${ google_compute_instance.${name}.network_interface.0.access_config.0.nat_ip }";
        priv =
          "\${ google_compute_instance.${name}.network_interface.0.network_ip }";
      in {
        ${name} = {
          value = with gcp; {
            inherit name domain;
            ip = { inherit pub priv; };
          };
        };
      });
  };
}
