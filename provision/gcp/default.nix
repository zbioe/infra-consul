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
          zone = mk' str gcp.zone "name of image";
          family = mk' str "nixos" "name of family";
          description = mk' str "description ${name}" "images description";
          source =
            mk' str "../../images/gcp/raw.tar.gz" "path for machine image";
        };
      });

      firewallModule = submodule ({ config, name, ... }: {
        options = {
          project = mk' str gcp.project "project";
          location = mk' str gcp.region "location";
          source_tags = mk' (listOf str) [ name ] "tags";
          target_tags = mk' (listOf str) [ name ] "tags";
          description = mk' str "description ${name}" "rule description";
          network = mk' str "default" "network interface used";
          allow = mk' (listOf rulesModule) [ ] "allowed rules";
          deny = mk' (listOf rulesModule) [ ] "denied rules";
        };
      });

      rulesModule = submodule {
        options = {
          protocol = mk' str "all" "protocol";
          ports = mk' (listOf str) [ ] "ports allowed";
        };
      };

      replicasModule = submodule ({ config, name, ... }: {
        options = {
          project = mk' str gcp.project "project";
          name = mk' str name "name of replica";
          machine_type = mk' str "e2-micro" "type of machine";
          tags = mk' (listOf str) [ name ] "tags";
          image = mk' str "nixos" "image used by instances";
          zone = mk' str gcp.zone "name of image";
          size = mk' int 20 "size of vm";
          network = mk' str "default" "network interface used";
          subnetwork = mk' str "n1" "subnetwork interface used";
        };
      });

    in {
      provision.gcp = {
        enable = mkBool' false "enable gcp provision";
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

        # rules submodule
        firewall = mkOption {
          type = (attrsOf firewallModule);
          default = { };
          description = "rules options";
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
    gcp = config.provision.gcp;
    networks = gcp.networks;
    images = gcp.images;
    replicas = gcp.replicas;
    firewall = gcp.firewall;
  in {
    terraform.required_providers =
      mkIf gcp.enable { google.source = "hashicorp/google"; };
    provider.google = mkIf gcp.enable {
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

      google_compute_firewall = attrsMap firewall (name: {
        ${name} = with firewall.${name}; {
          inherit name project description network source_tags target_tags allow
            deny;
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
