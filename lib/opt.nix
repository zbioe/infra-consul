{ lib, ... }:
let inherit (lib) mkOption types;
in {
  mk = type: default: mkOption { inherit type default; };

  mk' = type: default: description:
    mkOption { inherit type default description; };

  mkBool = default:
    mkOption {
      inherit default;
      type = types.bool;
      example = true;
    };

  mkBool' = default: description:
    mkOption {
      inherit default description;
      type = types.bool;
      example = true;
    };
}
