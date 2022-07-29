# Consul Deploy

Consul cluster in local vms server

## Requirements
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
## Build

* `nix build .#qcow` genarate `qcow2` image to use in `livirt`  

## Provision
Required to build image before apply.  
Required access to `./result`  
Add this access with `git add -Nf result`  
* `nix run` run `nix run ".#apply"`
* `nix run ".#apply"` run `terraform apply`
* `nix run ".#destroy"` run `terraform destroy`

## Deploy
Required access to `output.json` generated by provision.  
Add this access with `git add -Nf output.json`  
* `nix run ".#deploy"` run `colmena apply`
