{ pkgs, nixpkgs, system, ... }:
with pkgs;
let
  build = writeScriptBin "build" ''
    nix build .#$*
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

in mkShell {
  packages = [
    # custom
    build
    apply
    destroy
    deploy
    clean-ssh
    # pkgs
    consul
    consul-template
    envoy
    terraform
    terranix
    kube3d
    arion
    docker-client
    qemu-utils
    colmena
    vault
  ];
  shellHook = ''
    export NIX_PATH=${nixpkgs}
    export VAULT_ADDR=http://127.0.0.1:8200
    export VAULT_TOKEN="root-token"
  '';
}
