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
          location = mk' str azure.location "location of image";
          group = mk' str azure.group "resource group";
          tags = mk' (attrsOf str) { inherit (config) family; } "tags";
          name = mk' str name "name of image";
          family = mk' str "nixos" "name of family";
          source = mk' str "" "path for imgs or name of another volume";
        };
      });

      interfacesModule = submodule ({ config, name, ... }: {
        options = {
          group = mk' str azure.group "resource group";
          location = mk' str azure.location "location of image";
          name = mk' str name "name of interface";
          tags = mk' (attrsOf str) { "image" = cfg.image; } "tags";
          network = mk' str "default" "network interface used";
          subnetwork = mk' str "n1" "subnetwork interface used";
        };
      });

      replicasModule = submodule ({ config, name, ... }: {
        options = {
          group = mk' str azure.group "resource group";
          location = mk' str azure.location "location of image";
          name = mk' str name "name of replica";
          vm_size = mk' str "Standard_D1_v2" "VM Size configuration";
          tags = mk' (attrsOf str) { "image" = cfg.image; } "tags";
          image = mk' str "nixos" "image used by instances";
          disk_size = mk' int 20 "size of vm";
          interfaces = mk' (listOf str) [ name ] "interfaces used by replica";
          ssh_keys = mk' (listOf str) azure.ssh_keys "ssh keys to append in vm";
        };
      });

    in {
      provision.azure = {
        enable = mkBool' false "enable azure provision";
        group = mk' str "consul" "resource group";
        location = mk' str "East US 2" "location name";
        tags =
          mk' (attrsOf str) { app = "consul"; } "tags used in resource group";
        ssh_keys = mk' (listOf str) [ ] "ssh keys to append in vm";

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

        # interfaces submodule
        interfaces = mkOption {
          type = (attrsOf interfacesModule);
          default = { };
          description = "interface options";
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
    inherit (pkgs.lib.cfg) attrsMap listMap;

    azure = config.provision.azure;
    inherit (azure) networks images interfaces replicas;
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

      azurerm_storage_container = attrsMap images (name:
        with images.${name}; {
          ${name} = {
            inherit name;
            storage_account_name = "\${ azurerm_storage_account.${name}.name }";
            container_access_type = "private";
          };
        });

      azurerm_storage_account = attrsMap images (name: {
        ${name} = with images.${name};
          let
            inherit (builtins) filter split isList;
            inherit (lib) toLower concatMapStrings;
            regexp = "([a-z0-9]+)";
            splited_patterns = split regexp "${toLower group}${toLower name}";
            filter_patterns = filter (s: isList s) splited_patterns;
            uniq_name = concatMapStrings (s: toString s) filter_patterns;
          in {
            inherit location;
            name = uniq_name;
            resource_group_name = group;
            account_tier = "Standard";
            account_replication_type = "GRS";
            tags = { inherit name; };
          };
      });

      azurerm_storage_blob = attrsMap images (name:
        with images.${name}; {
          ${name} = {
            inherit source;
            name = "${name}.vhd";
            storage_account_name = "\${ azurerm_storage_account.${name}.name }";
            storage_container_name =
              "\${ azurerm_storage_container.${name}.name }";
            type = "Page";
            lifecycle = { ignore_changes = [ "source" ]; };
            timeouts = {
              create = "2h";
              update = "2h";
            };
          };
        });

      azurerm_image = attrsMap images (name:
        with images.${name}; {
          ${name} = {
            inherit name location;
            resource_group_name = group;
            os_disk = {
              os_type = "Linux";
              os_state = "Generalized";
              blob_uri = "\${ azurerm_storage_blob.${name}.url }";
              size_gb = 2;
            };
          };
        });

      azurerm_public_ip = attrsMap interfaces (name: {
        ${name} = with interfaces.${name}; {
          inherit name location;
          resource_group_name = group;
          allocation_method = "Static";
        };
      });

      azurerm_network_interface = attrsMap interfaces (name: {
        ${name} = with interfaces.${name}; {
          inherit name location;
          resource_group_name = group;
          ip_configuration = [{
            inherit name;
            subnet_id = "\${ azurerm_subnet.${subnetwork}.id }";
            private_ip_address_allocation = "Dynamic";
            public_ip_address_id = "\${ azurerm_public_ip.${name}.id }";
          }];
        };
      });

      azurerm_virtual_machine = attrsMap replicas (name:
        with replicas.${name};
        let inherit (replicas.${name}) interfaces;
        in {
          ${name} = {
            inherit name location tags vm_size;
            resource_group_name = group;
            delete_os_disk_on_termination = true;
            network_interface_ids =
              map (iname: "\${ azurerm_network_interface.${iname}.id }")
              interfaces;
            os_profile_linux_config = {
              ssh_keys = map (k: {
                key_data = k;
                path = "/home/main/.ssh/authorized_keys";
              }) ssh_keys;
              disable_password_authentication = true;
            };
            storage_image_reference = {
              id = "\${ azurerm_image.${image}.id }";
            };
            os_profile = {
              computer_name = name;
              admin_username = "main";
            };
            storage_os_disk = {
              inherit name;
              disk_size_gb = disk_size;
              create_option = "FromImage";
              os_type = "Linux";
              managed_disk_type = "Standard_LRS";
            };
          };
        });

    };

    output = attrsMap interfaces (name:
      let
        pub = "\${ azurerm_public_ip.${name}.ip_address }";
        priv = "\${ azurerm_network_interface.${name}.private_ip_address }";
      in {
        ${name} = {
          value = with azure; {
            inherit name;
            ip = { inherit pub priv; };
          };
        };
      });
  };
}
