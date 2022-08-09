{ pkgs, system, ... }:
with pkgs;
let
  inherit (builtins) readFile;
  inherit (writers) writeBash;
  build = writeScriptBin "build" ''
    nix build .#$*
  '';
  build-qcow = writeScriptBin "build-qcow" ''
    build qcow
    # add image to cache
    git add -Nf ./result
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
  clean-ssh = writeScriptBin "clean-ssh" ''
    nix run .#clean-ssh
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
    minikube
    apply
    apply-local
    apply-gcp
    destroy-local
    destroy-gcp
    destroy
    deploy
    clean-ssh
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
