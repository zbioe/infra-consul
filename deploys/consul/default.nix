{ name, nodes, pkgs, ... }: {
  imports = [ ../../generators/minimal-libvirt.nix ];

  networking.hostName = name;
  environment.systemPackages = with pkgs; [ tmux ];

  deployment = {
    tags = [ "consul" "server" "replica" ];
    targetUser = "main";
    targetPort = 22;
  };
}
