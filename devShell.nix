{ pkgs, system, ... }:
let
  inherit (pkgs) writeScriptBin mkShell;
  # Build images
  build = writeScriptBin "build" ''
    set -eu
    image=$1
    nix build --out-link "./images/$image" .#$image
    # add image to cache
    git add -Nf images/$image
  '';
  build-qcow = writeScriptBin "build-qcow" ''
    build qcow
  '';
  build-gce = writeScriptBin "build-gce" ''
    build gce
  '';
  build-azure = writeScriptBin "build-azure" ''
    build azure
  '';

  # Apply using terraform
  apply = writeScriptBin "apply" ''
    env=''${1:-libvirt}
    # defaults to libvirt
    nix run .#apply-$env
  '';
  apply-libvirt = writeScriptBin "apply-libvirt" ''
    apply libvirt
  '';
  apply-gcp = writeScriptBin "apply-gcp" ''
    apply gcp
  '';
  apply-azure = writeScriptBin "apply-azure" ''
    apply azure
  '';

  # Destroy using terraform
  destroy = writeScriptBin "destroy" ''
    env=''${1:-libvirt}
    # defaults to libvirt
    nix run .#destroy-$env
  '';
  destroy-libvirt = writeScriptBin "destroy-libvirt" ''
    destroy libvirt
  '';
  destroy-gcp = writeScriptBin "destroy-gcp" ''
    destroy gcp
  '';
  destroy-azure = writeScriptBin "destroy-azure" ''
    destroy azure
  '';

  # Deploy nix using colmena
  deploy = writeScriptBin "deploy" ''
    env=''${1:-libvirt}
    nix run .#deploy-$env
  '';
  deploy-libvirt = writeScriptBin "deploy-libvirt" ''
    deploy libvirt
  '';
  deploy-gcp = writeScriptBin "deploy-gcp" ''
    deploy gcp
  '';
  deploy-azure = writeScriptBin "deploy-azure" ''
    deploy azure
  '';

  # Clean SSH authorized keys
  clean-ssh = writeScriptBin "clean-ssh" ''
    env=''${1:-"libvirt""}
    [[ "$env" == all ]] && ./scripts/clean-ssh.sh
    nix run .#clean-ssh-$env
  '';
  clean-ssh-libvirt = writeScriptBin "clean-ssh-libvirt" ''
    nix run .#clean-ssh-libvirt
  '';
  clean-ssh-gcp = writeScriptBin "clean-ssh-gcp" ''
    nix run .#clean-ssh-gcp
  '';
  clean-ssh-azure = writeScriptBin "clean-ssh-azure" ''
    nix run .#clean-ssh-azure
  '';

  # Up and Running local vault using docker-compose by arion
  local-vault = writeScriptBin "local-vault" ''
    nix run .#local-vault
  '';
  # Up and running local k8s using k3d
  local-k8s = writeScriptBin "local-k8s" ''
    nix run .#local-k8s
  '';
in mkShell {
  packages = with pkgs; [
    # build images
    build
    build-qcow # libvirt
    build-gce # gcp
    build-azure # azure

    # provision apply
    apply
    apply-libvirt
    apply-gcp
    apply-azure

    # provision destroy
    destroy
    destroy-libvirt
    destroy-gcp
    destroy-azure

    # deploy to nixos
    deploy
    deploy-libvirt
    deploy-gcp
    deploy-azure

    # clean ssh authorized keys
    clean-ssh
    clean-ssh-libvirt
    clean-ssh-gcp
    clean-ssh-azure

    # start local vault
    local-vault
    # start local k8s
    local-k8s

    # pkgs
    consul
    consul-template
    vault
    envoy
    terraformWithPlugins
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
