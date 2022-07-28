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
  tests = writeScriptBin "tests" ''
    nix run .#tests
  '';
in mkShell {
  packages = [
    # custom
    build
    apply
    destroy
    tests
    # pkgs
    consul
    consul-template
    terraform
    terranix
    kube3d
    arion
    docker-client
    qemu-utils
    colmena
  ];
  shellHook = ''
    export NIX_PATH=${nixpkgs}
  '';
}
