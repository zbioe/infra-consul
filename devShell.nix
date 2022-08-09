{ pkgs, system, ... }:
with pkgs;
let
  inherit (builtins) readFile;
  inherit (writers) writeBash;
  build = writeScriptBin "build" ''
    env=$1
    image=$2
    nix build --out-link "./env/$env/image" .#$image
    # add image to cache
    git update-index --assume-unchanged env/$env/image
  '';
  build-qcow = writeScriptBin "build-qcow" ''
    build local qcow
  '';
  build-gce = writeScriptBin "build-gce" ''
    build gcp gce
  '';
  apply = writeScriptBin "apply" ''
    # defaults to local
    nix run .#apply
  '';
  apply-local = writeScriptBin "apply-local" ''
    nix run .#apply-local
  '';
  apply-gcp = writeScriptBin "apply-gcp" ''
    nix run .#apply
  '';
  destroy = writeScriptBin "destroy" ''
    # defaults to local
    nix run .#destroy
  '';
  destroy-local = writeScriptBin "destroy-local" ''
    nix run .#destroy-local
  '';
  destroy-gcp = writeScriptBin "destroy-gcp" ''
    nix run .#destroy-gcp
  '';
  deploy = writeScriptBin "deploy" ''
    nix run .#deploy
  '';
  deploy-local = writeScriptBin "deploy-local" ''
    nix run .#deploy-local
  '';
  deploy-gcp = writeScriptBin "deploy-gcp" ''
    nix run .#deploy-gcp
  '';
  clean-ssh = writeScriptBin "clean-ssh" ''
    nix run .#clean-ssh
  '';
  clean-ssh-local = writeScriptBin "clean-ssh-local" ''
    nix run .#clean-ssh-local
  '';
  clean-ssh-gcp = writeScriptBin "clean-ssh-gcp" ''
    nix run .#clean-ssh-gcp
  '';
  local-vault = writeScriptBin "local-vault" ''
    nix run .#local-vault
  '';
  local-k8s = writeScriptBin "local-k8s" ''
    nix run .#local-k8s
  '';
  terranix-apply =
    writeBash "terraform-apply" (readFile ./scripts/terranix-apply.sh);
  terranix-destroy =
    writeBash "terraform-destroy" (readFile ./scripts/terranix-destroy.sh);
in mkShell {
  packages = [
    # custom
    build
    build-qcow
    build-gce
    minikube
    apply
    apply-local
    apply-gcp
    destroy-local
    destroy-gcp
    destroy
    deploy
    deploy-local
    deploy-gcp
    clean-ssh
    clean-ssh-local
    clean-ssh-gcp
    local-vault
    local-k8s
    # terranix
    # terranix-apply
    # terranix-destroy
    # pkgs
    consul
    consul-template
    vault
    envoy
    terraform
    terranix
    kube3d
    kubernetes-helm
    arion
    docker-client
    qemu-utils
    colmena
    vault
    bashInteractive
  ];
  shellHook = ''
    export NIX_PATH=${pkgs.path}
    export VAULT_ADDR=''${CD_VAULT_ADDR:-"http://10.0.62.1:8200"}
    export VAULT_TOKEN=''${CD_VAULT_TOKEN:-"root-token"}
  '';
}
