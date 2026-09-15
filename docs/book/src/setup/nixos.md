# NixOS

Max ships a multi-instance NixOS module at
[`nix/module.nix`](https://github.com/max-labs/max/blob/master/nix/module.nix).
It runs one or more agents under systemd with hardening defaults appropriate
for an internet-facing process, modelled on `services.restic.backups`.

## The package

The module invokes `${pkgs.max}/bin/max daemon`. `pkgs.max` is
not yet in nixpkgs; it is tracked in
[#5987](https://github.com/max-labs/max/issues/5987). Until it lands,
build the binary yourself and point the module at it with the `package` option:

<div class="os-tabs-src">

#### nix

```nix
services.max.instances.me.package =
  pkgs.callPackage ./max.nix { };
```

</div>

For the same reason, `nix run github:max-labs/max` does not launch the
agent. `nix run` resolves `apps.<system>.default` then `packages.<system>.default`;
this flake defines no `apps`, and its `packages.default` is the Rust toolchain
(for the dev shell), so the command would run the toolchain derivation, not
Max. On any other platform, [`install.sh`](./linux.md) is the supported
path.

## Single instance

Membership in `services.max.instances.<name>` is the activation signal;
there is no top-level `enable`. Each instance gets its own systemd unit, state
directory, and system user.

<div class="os-tabs-src">

#### nix

```nix
{ config, pkgs, ... }: {
  imports = [ ./path/to/max/nix/module.nix ];

  age.secrets.max-bot-token.file = ./secrets/max-bot-token.age;

  services.max.instances.me = {
    environmentFile = config.age.secrets.max-bot-token.path;
    settings = {
      providers.models.anthropic.home.model = "claude-sonnet-4-6";
      agents.assistant = {
        model_provider = "anthropic.home";
        risk_profile = "assistant";
        channels = [ "telegram.home" ];
      };
      risk_profiles.assistant = { };
      channels.telegram.home = {
        enabled = true;
        bot_token = "$BOT_TOKEN";   # systemd $VAR, substituted from environmentFile at start
        allowed_users = [ "12345" ];
      };
    };
  };
}
```

</div>

`settings` mirrors `~/.max/config.toml` as a Nix attrset, rendered to
`${dataDir}/config.toml` (mode `0600`). Secrets travel through
`environmentFile`, never `settings`: the unit's `ExecStartPre` runs `envsubst`
so `$VAR` references resolve at start, keeping the `/nix/store` copy free of
plaintext. The [config schema](../providers/configuration.md) (section headers,
type/alias convention) is identical to every other platform.

## Multiple instances

The module is `attrsOf submodule`-shaped, so N tenants on one host read the same
as one. Instances may share a user when exactly one creates it and the rest set
`createUser = false`.

<div class="os-tabs-src">

#### nix

```nix
services.max.instances = {
  alice = { environmentFile = "/run/secrets/alice/identity.env"; settings = { /* … */ }; };
  bob   = { environmentFile = "/run/secrets/bob/identity.env";   settings = { /* … */ }; };
};
```

</div>

## Options

The full option surface (`package`, `user`, `group`, `createUser`, `dataDir`,
`settings`, `environmentFile`, `extraConfig`, `bindReadOnlyPaths`) and the
secrets pattern are documented in
[`nix/README.md`](https://github.com/max-labs/max/blob/master/nix/README.md).
To override a `serviceConfig` field, use the standard NixOS escape hatch rather
than a module option:

<div class="os-tabs-src">

#### nix

```nix
systemd.services."max-me".serviceConfig.MemoryMax = "512M";
```

</div>

## Next

- [Service management](./service.md): the systemd unit Max generates on non-Nix hosts
- [Providers → Configuration](../providers/configuration.md): the config schema `settings` mirrors
