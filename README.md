# Infra Consul
Infra environment for deploy consul with Federation and vault integration
in differents environments with same deploy.

## Steps Simplified
 - [gcp/azure federation with vault integration](./steps.txt)
## Requirements

Have some dependecies accordingly what environment are you using.

### Libvirtd
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

### GCP
Need instalation of gcloud, or append it inside devShell.  
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

### Azure
required az command. you can put it inside devShell too.  
``` nix
{
  environment.systemPackages = [
    pkgs.azure-cli 
  ];
}
```

Get auth to Azure with:  
``` bash
az login
```

## Environment

If you use external VAULT, it's required to set the envs to point to it.  
To set it, use:  

``` bash
IC_VAULT_ADDR=https://vault:443
IC_VAULT_TOKEN=root-token
```

## Build

By default it will build libvirt  

### Libvirtd
To build libvirt Image to be imported use:  
``` bash
nix build .#qcow # or `build-qcow`
```

### GCP
To build GCP Image use:  
``` bash
nix build .#gce # or `build-gce`
```

### Azure
To build azure Image to be imported use:  
``` bash
nix build .#azure # or `build-azure`
```

## Provision
Required to build image before apply.  
Required access to `./result`. Add this access with `git add -Nf result`  

It will call terraform in the end with the configuration made by terranix  
Converting the `config.nix` files in `config.tf.json`  

In the end of provision it will output an JSON with the values of each machine created.  

### Operations
Defaults to `libvirt`  
``` bash
# Apply infra
nix run ".#apply" # or `nix run` or `apply`
# Destroy infra
nix run ".#destroy" # or `nix run` or `destroy`
```

#### Libvirt
Provide infra in Libvirtd environment.  
``` bash
# Apply
nix run ".#apply-libvirt" # or `apply-libvirt`
# Destroy
nix run ".#destroy-libvirt" # or `destroy-libvirt`
```

#### GCP
Provide infra in GCP environment.  
``` bash
# Apply
nix run ".#apply-gcp" # or `apply-gcp`
# Destroy
nix run ".#destroy-gcp" # or `destroy-gcp`
```

#### Azure
Provide infra in Azure environment.  
``` bash
# Apply
nix run ".#apply-azure" # or `apply-azure`
# Destroy
nix run ".#destroy-azure" # or `destroy-azure`
```

## Deploy
Required access to `output.json` generated by provision.  
Add this access with `git add -Nf output.json`  
Required vault access. you can pass Environment or use an local vault.  

Deploy uses [colmena](https://github.com/zhaofengli/colmena) as backend.  
For deploy, you can follow all patterns of provision, but replacing `apply` to `deploy`  

It defaults to libvirt  
``` bash
nix run ".#deploy" # or `deploy`
```

### Libvirt
For deploy to libvirt explicit use:  
``` bash
nix run ".#deploy-libvirt" # or `colmena deploy --on @libvirt` # or `deploy-libvirt`
```

### GCP
For deploy to GCP use:
``` bash
nix run ".#deploy-gcp" # or `colmena deploy --on @gcp` # or `deploy-gcp`
```

### Azure
For deploy to Azure use:
``` bash
nix run ".#deploy-azure" # or `colmena deploy --on @azure` # or `deploy-azure`
```

## Vault
Use vault as pki and secret manager.  
To configure it, set Environment with token and addr.  
And then use:  
``` bash
./scripts/vault-init.sh
```
to configure it.  

### Environment
Set environment vars with addr and token. If you are using local-vault, you don't need to set it.  
``` bash
IC_VAULT_ADDR=https://vault:443
IC_VAULT_TOKEN=root-token
```

### Local-Vault
Use docker-compose by arion-compose to run a dev local-vault.  
For libvirt environment you can use local vault.  
Start vault dev server in `http://127.0.0.1:8200`with:  
``` bash
local-vault # or arion up
```

## K8s
Federation in Kubernetes can be configured using scripts and devShell alias.

If you are using `libvirt` environment, you can use an local-k8s

### Federation
Configure it with federation with
``` bash
./scripts/k8s/configure.sh # configure k8s
```

### Local K8s
Start local kubernetes with k3d for libvirt local tests.
``` bash
local-k8s # start k3d local
```
