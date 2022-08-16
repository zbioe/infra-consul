# Consul Deploy

Consul cluster in local vms server

## Requirements

Have some dependecies required for use modules

# LIBVIRTD
`libvirtd` needs to works in your environment.  
Add follow options to your `configuration.nix`:  
``` nix
{
  users.users.myname.extraGroups = [
    "qemu-libvirtd" "libvirtd" 
    "wheel" "video" "audio" "disk" "networkmanager"
  ]; 
  virtualisation.libvirtd.enable = true;
  # optional
  boot.kernelModules = [ "kvm-amd" "kvm-intel" ];
  # optional
  services.qemuGuest.enable = true;
}
```

# GCP
``` nix
{
  environment.systemPackages = [
    pkgs.google-cloud-sdk 
  ];
}
```

Get auth to GCP with:
``` bash
gcloud auth application-default login
```

## Build

* `nix build .#qcow` genarate `qcow2` image to use in `livirt`  

## Provision
Required to build image before apply.  
Required access to `./result`  
Add this access with `git add -Nf result`  
* `nix run` run `nix run ".#apply"`
* `nix run ".#apply"` run `terraform apply`
* `nix run ".#destroy"` run `terraform destroy`

## Vault
start vault dev server in `http://127.0.0.1:8200`

``` bash
arion up # or local-vault
```

## Deploy
Required access to `output.json` generated by provision.  
Add this access with `git add -Nf output.json`  
Required vault access `local-vault` start and populate a local docker vault.  
* `nix run ".#deploy"` run `colmena apply`  

## K8s
start local kubernetes with k3d and configure it to do federation

``` bash
local-k8s # start k3d local
./scripts/configure.sh # configure local k8s
```

