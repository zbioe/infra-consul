let
  # consul group
  group = "consul";
  user = "consul";
  mkCmd = field: path: [ "vault" "kv" "get" "--field=${field}" "kv/${path}" ];
  # gen = text: { inherit group user text; };
in {
  encryption = let keyCommand = mkCmd "key" "consul/config/encryption";
  in { inherit group user keyCommand; };
}
