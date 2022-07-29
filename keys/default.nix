datacenter:
let
  # consul group
  group = "consul";
  user = "consul";
  # to production use
  mKeyCommand = datacenter: key: [
    "vault"
    "read"
    "--field=${key}"
    "secret/${datacenter}"
  ];
  #
  # gen = key:
  #   let keyCommand = (mKeyCommand datacenter key);
  #   in { inherit group user keyCommand; };
  gen = text: { inherit group user text; };
in {
  domain = (gen "d");
  datacenter = (gen datacenter);
  primary_datacenter = (gen "c1");
}
