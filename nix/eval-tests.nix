{
  nixpkgs ? <nixpkgs>,
  system ? "x86_64-linux",
}:

let
  pkgs = import nixpkgs { inherit system; };
  lib = pkgs.lib;

  stubPackage =
    pkgs.runCommand "max-eval-stub"
      {
        meta.mainProgram = "max";
      }
      ''
        mkdir -p $out/bin
        cat > $out/bin/max <<'EOF'
        #!${pkgs.runtimeShell}
        exit 0
        EOF
        chmod +x $out/bin/max
      '';

  mkInstance =
    attrs:
    {
      package = stubPackage;
      settings.default_provider = "anthropic";
    }
    // attrs;

  evalConfig =
    instances:
    (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        ./module.nix
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          system.stateVersion = "26.05";
        }
        {
          services.max.instances = instances;
        }
      ];
    }).config;

  failedAssertions =
    instances:
    builtins.filter (assertion: !assertion.assertion) (evalConfig instances).assertions;

  assertionMessages =
    assertions:
    lib.concatStringsSep "\n" (map (assertion: assertion.message) assertions);

  assertPasses =
    name: instances:
    let
      failed = failedAssertions instances;
    in
    if failed == [ ] then
      true
    else
      throw "${name}: expected module eval to pass, but assertion(s) failed: ${assertionMessages failed}";

  assertFailsWith =
    name: expectedSubstring: instances:
    let
      failed = failedAssertions instances;
      matched = lib.any (assertion: lib.hasInfix expectedSubstring assertion.message) failed;
    in
    if matched then
      true
    else
      throw "${name}: expected assertion containing `${expectedSubstring}`, got: ${assertionMessages failed}";
in
{
  duplicateCreatedUsersFail = assertFailsWith "duplicate created users" "same `user` while also setting `createUser = true`" {
    first = mkInstance {
      user = "max-shared";
    };
    second = mkInstance {
      user = "max-shared";
    };
  };

  sharedUserWithSingleCreatorPasses = assertPasses "shared user with one creator" {
    owner = mkInstance { };
    shared = mkInstance {
      user = "max-owner";
      group = "max-owner";
      createUser = false;
      dataDir = "/var/lib/max-shared";
    };
  };

  distinctCreatedUsersMayShareGroup = assertPasses "distinct created users sharing group" {
    first = mkInstance {
      group = "max-shared-group";
    };
    second = mkInstance {
      group = "max-shared-group";
    };
  };
}
