let
  # consul group
  group = "consul";
  user = "consul";
  secret = "consul";
  mkCmd = field: [ "vault" "kv" "get" "--field=${field}" "secret/${secret}" ];
  # gen = text: { inherit group user text; };
in {
  encryption = let keyCommand = mkCmd "encryption.hcl";
  in { inherit group user keyCommand; };
}
