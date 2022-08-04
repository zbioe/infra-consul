{ pkgs, system, ... }:
with pkgs;
let
  build = writeScriptBin "build" ''
    nix build .#$*
  '';
  build-qcow = writeScriptBin "build-qcow" ''
    build qcow
  '';
  apply = writeScriptBin "apply" ''
    nix run .#apply
  '';
  destroy = writeScriptBin "destroy" ''
    nix run .#destroy
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
in mkShell {
  packages = [
    # custom
    build
    build-qcow
    apply
    destroy
    deploy
    clean-ssh
    local-vault
    local-k8s
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
  ];
  shellHook = ''
    export NIX_PATH=${pkgs.path}
    export VAULT_ADDR=''${CD_VAULT_ADDR:-"http://10.0.62.1:8200"}
    export VAULT_TOKEN=''${CD_VAULT_TOKEN:-"root-token"}
  '';
}
