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
          group = mk' str azure.group "resource group";
          location = mk' str azure.location "resource group";
          name = mk' str name "name of network";
          tags = mk' (attrsOf str) { env = "test"; } "tags marked in network";
          cidr_ranges =
            mk' (listOf str) [ "10.0.0.0/16" ] "cidr ranges network";
          dns_servers = mk' (listOf str) [ "1.1.1.1" "8.8.8.8" ] "dns servers";
          subnetworks = mk' (attrsOf subnetworksModule) { } "subnetwork module";
        };
      });

      subnetworksModule = submodule ({ config, name, ... }: {
        options = {
          name = mk' str name "name of subnetwork";
          cidr_ranges =
            mk' (listOf str) [ "10.0.1.0/16" ] "cidr ranges network";
          group = mk' str azure.group "resource group";
        };
      });

      imagesModule = submodule ({ config, name, ... }: {
        options = {
          project = mk' str azure.project "project";
          location = mk' str azure.location "location";
          labels = mk' (attrsOf str) { name = name; } "labels";
          name = mk' str name "name of image";
          zone = mk' str azure.zone "name of image";
          family = mk' str "nixos" "name of family";
          description = mk' str "description ${name}" "images description";
          source = mk' str "" "path for imgs or name of another volume";
        };
      });

      replicasModule = submodule ({ config, name, ... }: {
        options = {
          project = mk' str gcp.project "project";
          name = mk' str name "name of replica";
          machine_type = mk' str "e2-micro" "type of machine";
          tags = mk' (attrsOf str) { "name" = name; } "tags";
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
        group = mk' str "consul" "resource group";
        location = mk' str "East US 2" "location name";
        tags =
          mk' (attrsOf str) { app = "consul"; } "tags used in resource group";

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

        # # replica submodule
        # replicas = mkOption {
        #   type = (attrsOf replicasModule);
        #   default = { };
        #   description = "replicas options";
        # };
      };
    };
  config = let
    inherit (builtins) attrNames;
    inherit (lib) mkIf readFile assertMsg;
    inherit (lib.strings) removeSuffix;
    inherit (pkgs.lib.cfg) attrsMap listMap;
    azure = config.provision.azure;
    networks = azure.networks;

  in {
    terraform.required_providers =
      mkIf azure.enable { azurerm.source = "hashicorp/azurerm"; };
    provider.azurerm = mkIf azure.enable {
      features = {
        virtual_machine = {
          delete_os_disk_on_deletion = true;
          graceful_shutdown = false;
          skip_shutdown_and_force_delete = false;
        };
      };
    };

    resource = let rg = "\${ azurerm_resource_group.${azure.group} }";
    in mkIf azure.enable {
      azurerm_resource_group.${azure.group} = {
        name = azure.group;
        location = azure.location;
        tags = azure.tags;
      };

      azurerm_network_security_group = attrsMap networks (name: {
        ${name} = with networks.${name}; {
          inherit name location;
          resource_group_name = group;
        };
      });

      azurerm_virtual_network = attrsMap networks (name: {
        ${name} = with networks.${name}; {
          inherit location name tags dns_servers;
          address_space = cidr_ranges;
          resource_group_name = group;
        };
      });

      azurerm_subnet = attrsMap networks (name:
        let subnetworks = networks.${name}.subnetworks;
        in attrsMap subnetworks (sname:
          with subnetworks.${sname}; {
            ${sname} = {
              name = sname;
              resource_group_name = group;
              virtual_network_name =
                "\${ azurerm_virtual_network.${name}.name }";
              address_prefixes = cidr_ranges;
            };
          }));
    };

    # TODO:
    # subnet_network_security_group_association =
    # "\${ azurerm_network_security_group.${name}.id }";

    # output = attrsMap replicas (name:
    #   let
    #     inherit (builtins) head;
    #     repl = replicas.${name};
    #     pub =
    #       "\${ google_compute_instance.${name}.network_interface.0.access_config.0.nat_ip }";
    #     priv =
    #       "\${ google_compute_instance.${name}.network_interface.0.network_ip }";
    #   in {
    #     ${name} = {
    #       value = with gcp; {
    #         inherit name domain;
    #         ip = { inherit pub priv; };
    #       };
    #     };
    #   });
  };
}
