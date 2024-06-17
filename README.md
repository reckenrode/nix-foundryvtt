# nix-foundryvtt

This is repo packages FoundryVTT for use with NixOS and Nix. It only includes the server component.
We use FoundryVTT intermitently, but I’ve subscribed to notifications on foundryvtt/foundryvtt in
the hope I can do a better job keeping up to date with releases when we’re not actively playing.

The NixOS module targets the latest release of NixOS. That’s 24.05. 

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

This repo packages only a single release of FoundryVTT; typically the most up-to-date version.  When Foundry releases a new version, here's a procedure for upgrading to the latest release.

1. Download the new Linux/NodeJS version of Foundry from your licensed account at https://foundryvtt.com/

2. Run `nix build .#foundryvtt.passthru.updateScript && ./result <path to download>/FoundryVTT-<version>.zip <release type>`
   * `<release type>` is one of the above release types.

3. Commit all the changes to a branch, test them, and create a PR for the update.
