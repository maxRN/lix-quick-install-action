{
  lib,
  callPackage,
  pkgs,

  lixPackageSets,
}:

let
  inherit (lib) listToAttrs nameValuePair replaceStrings;

  makeStoreArchive = callPackage ./make-store-archive.nix { };

  # Makes a set of Lix packages, where the version is the key and the package is the value.
  #
  # Accepts:
  # - f: A function that accepts a system, and a Lix package, that produces the final value assigned to the version in
  #   the set.
  # - lixen: A function that accepts a system, and returns a list of Lix packages to include in the set.
  # - system: The system to produce a set for.
  mkLixSet =
    f: lixen: system:
    listToAttrs (
      map (lix: nameValuePair "v${replaceStrings [ "." ] [ "_" ] lix.version}" (f system lix)) (
        lixen system
      )
    );

  # Accepts a system, and returns a list of Lix derivations that are supported on that system.
  lixVersionsForSystem =
    system:
    let
      # enabling LTO on darwin systems seems to cause all manner of weird and wacky bustage on lix 2.92 and newer.
      # until that's fixed, or until nixpkgs disables it there as well, this function will produce lix derivations that
      # build with LTO disabled on darwin.
      # https://github.com/NixOS/nixpkgs/pull/398141#discussion_r2091831651
      # https://git.lix.systems/lix-project/lix/issues/832
      disableLTO =
        lix:
        if !(builtins.elem system lib.platforms.darwin) then
          lix
        else
          lix.overrideAttrs (prev: {
            mesonFlags = (builtins.filter (flag: !(lib.hasInfix "b_lto" flag)) prev.mesonFlags) ++ [
              (lib.mesonBool "b_lto" false)
            ];
          });
    in
    [
      (disableLTO lixPackageSets.lix_2_93.lix)
      (disableLTO lixPackageSets.lix_2_92.lix)
      lixPackageSets.lix_2_91.lix
    ];
in
rec {
  # Accepts a system, and returns an attribute set from supported versions to Lix derivations.
  lixVersionsFor = mkLixSet (_: lix: lix) lixVersionsForSystem;
  # Accepts a system, and returns an attribute set from supported versions to a Lix archive for that version.
  lixArchivesFor = mkLixSet makeStoreArchive lixVersionsForSystem;

  # Accepts a system, and returns a derivation producing a folder containing Lix archives for all Lix versions
  # supported by the given system.
  combinedArchivesFor =
    system:
    pkgs.symlinkJoin {
      name = "lix-archives";
      paths = builtins.attrValues (lixArchivesFor system);
    };
}
