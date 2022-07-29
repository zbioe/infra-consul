(_: prev: {
  # extend lib
  lib = prev.lib // import ../lib { inherit (prev) lib; };
})
