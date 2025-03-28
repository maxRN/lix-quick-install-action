let
  pkgs = import (import ./npins).nixpkgs { };
in

pkgs.hello
