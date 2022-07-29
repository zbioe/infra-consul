let
  # consul group
  group = "consul";
  user = "consul";
  # to production use
  # keyCommand = [ "vault" "read" "--field=env" "secret/mysecret" ]
  gen = text: { inherit group user text; };
in {
  domain = gen "d";
  datacenter = gen "c1";
}
