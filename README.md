# nix-foundryvtt

This is repo packages FoundryVTT for use with NixOS and Nix. It only includes the server component.
We use FoundryVTT intermitently, but I’ve subscribed to notifications on foundryvtt/foundryvtt in
the hope I can do a better job keeping up to date with releases when we’re not actively playing.

The NixOS module targets the latest release of NixOS. That’s 24.05. 

## Using the Module

To use the module, add it to the modules list in your NixOS configuration. See below for an example `flake.nix` and
`configuration.nix`. See [modules/foundryvtt/default.nix][1] for the available options.

#### `flake.nix`
```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.foundryvtt.url = "github:reckenrode/nix-foundryvtt";

  outputs = { self, nixpkgs, foundryvtt }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
	    inputs.foundryvtt.nixosModules.foundryvtt
      ];
    };
  };
}
```

#### `configuration.nix`

```nix
{
  services.foundryvtt = {
    enable = false;
    hostName = "<hostname goes here>";
    minifyStaticFiles = true;
    proxyPort = 443;
    proxySSL = true;
    upnp = false;
  };
}
```

### Using a different version of Foundry VTT

By default, the module uses `foundryvtt`, which corresponds to FoundryVTT v11. You should change the module to
the version of FoundryVTT you plan to run on your server. See below for how to use a different package version.

```nix
{ inputs, pkgs, ... }:

{
  services.foundryvtt = {
    enable = false;
    hostName = "<hostname goes here>";
    minifyStaticFiles = true;
    package = inputs.foundryvtt.packages.${pkgs.system}.foundryvtt_12; # Sets the version to the latest FoundryVTT v12.
    proxyPort = 443;
    proxySSL = true;
    upnp = false;
  };
}
```

### Preventing Garbage Collection of the FoundryVTT Zip File

Because FoundryVTT is not available for download without a login, it has to be added manually to the store. Doing this
per the instructions when you first build your configuration will add the file to the store, but the file is at risk
of being garbage collected when `nix-collect-garbage` is run. To prevent the file from being garbage collected, create a
GC root. As long as the created root exists, it will be used as necessary when you rebuild or update your configs.

The file naming convention should match the name downloaded from the FoundryVTT website. Older releases omit the
platform name from the file, but newer ones include it. The following examples use the platform name, but you should
exclude it if you are using an older version. Note that all platforms should be using the Linux download.

**Note:** You will need to repeat this procedure for every version of FoundryVTT that you use.

```shell
$ nix-store --add-fixed sha256 FoundryVTT-Linux-<version>.zip
/nix/store/<hash>-FoundryVTT-Linux-<version>.zip
$ mkdir -p <some path>
$ nix-store --add-root <some path>/FoundryVTT-Linux-<version>.zip -r /nix/store/<hash>-FoundryVTT-Linux-<version>.zip
<some path>/FoundryVTT-Linux-<version>.zip
$ ls -al <some path>
total 0
drwxr-xr-x   3 reckenrode staff   96 Jun 18 18:33 ./
drwxr-x---+ 75 reckenrode staff 2400 Jun 18 18:33 ../
lrwxr-xr-x   1 reckenrode staff   65 Jun 18 18:33 FoundryVTT-Linux-<version>.zip -> /nix/store/<hash>-FoundryVTT-Linux-<version>.zip
```

## Versioning Policy

nix-foundryvtt has version information for all available releases of Foundry VTT. It provides packages for the latest
stable releases of v9, v10, v11, and v12. `foundryvtt_latest` corresponds to the latest version (currently v12).

### Overriding the FoundryVTT Version

The FoundryVTT version can be overriden using `overrideAttrs`.

* Specify the `majorVersion` and `releaseType` to specify the major version and release you want to install.
  * `majorVersion` corresponds to the major version as used by FoundryVTT.
  * `releaseType` is one of `prototype`, `development`, `testing`, or `stable`. This specifies the least stable release
    the resolver should match. The default is `stable`.
    * `prototype` will match all release types.
    * `development` will match `development`, `testing`, and `stable`.
    * `testing` will match `testing` and `stable`.
    * `stable` will match only `stable`.
* Specify `version` to use a specific version based on the semver version (e.g., `12.0.0+327` to install
  FoundryVTT 12.327). Specifying a `version` ignores the release type.
* Specify `build` to use a specific build (e.g., `327` to install FoundryVTT 12.327). Specifying a `build` ignores the
  release type.

## Performing a Foundry Upgrade

1. Download the new Linux version of Foundry from your licensed account at https://foundryvtt.com/.
   Note: FoundryVTT now offers a separate, Node.js download. Use the Linux download.

2. Run `nix build .#foundryvtt.passthru.updateScript && ./result <path to download>/FoundryVTT-Linux-<version>.zip <release type>`
   * `<release type>` is one of the above release types.

3. Commit all the changes to a branch, test them, and create a PR for the update.

[1]: https://github.com/reckenrode/nix-foundryvtt/blob/main/modules/foundryvtt/default.nix
