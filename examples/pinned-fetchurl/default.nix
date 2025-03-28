let
  pkgs =
    import
      (fetchTarball "https://github.com/NixOS/nixpkgs/archive/bd3bac8bfb542dbde7ffffb6987a1a1f9d41699f.tar.gz")
      { };
in

pkgs.hello
