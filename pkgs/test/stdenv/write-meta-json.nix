{
  lib,
  pkgs,
}:

let
  inherit (pkgs.testers) testEqualArrayOrMap;
  inherit (lib.asserts) assertMsg;
  jq = lib.getExe pkgs.jq;
  script = ''
    mkdir -p $out
    nixLog "Running nix-meta hook"
    writeMetaInAllOutputs
    declare -ig writeMetaJSONInstalled=1

    nixLog "$(cat $out/nix-support/meta.json)"
    for value in "''${valuesArray[@]}"; do
      nixLog "Testing jq query '$value'"
      actualArray+=( "$(${jq} -cr "$value" $out/nix-support/meta.json)" )
    done
    nixLog "Done"
  '';
in
{
  test_nested_meta =
    (testEqualArrayOrMap {
      name = "temp_name";
      #valuesArray contains jq queries
      valuesArray = [
        ".name"
        ".version"
        ".cpe.key"
        "keys[]"
      ];
      expectedArray = [
        "temp_pname"
        "test_version"
        "nested_value"
        "cpe\nname\npname\nversion"
      ];
      inherit script;
    }).overrideAttrs
      {
        pname = "test_pname";
        version = "test_version";
        meta = {
          cpe = {
            key = "nested_value";
          };
        };
      };

  test_string_context =
  let
    test = builtins.tryEval
      ((pkgs.runCommand "test" {} '''').overrideAttrs { meta.vendor = lib.getExe pkgs.jq; });
  in
    assert assertMsg (test.value == false) "test_string_context should not eval successfully.";
    builtins.toFile "test_string_context" (toString test.value);


  # Test derivation without pname or name?
}
