# nix-foundryvtt

This is repo packages FoundryVTT for use with NixOS and Nix. It only includes the server component.
We use FoundryVTT intermitently, but I’ve subscribed to notifications on foundryvtt/foundryvtt in
the hope I can do a better job keeping up to date with releases when we’re not actively playing.

The NixOS module targets the latest release of NixOS. That’s 22.05. Once 22.11 is released, it will
be updated for NixOS 22.11 if necessary. This should probably be upstreamed into nixpkgs eventually.

## Performing a Foundry Upgrade

This repo packages only a single release of FoundryVTT; typically the most up-to-date version.  When Foundry releases a new version, here's a procedure for upgrading to the latest release.

1. Download the new Linux/NodeJS version of Foundry from your licensed account at https://foundryvtt.com/

2. Run `nix build .#foundryvtt.passthru.updateScript && ./result <path to download>/FoundryVTT-<version>.zip`

3. Commit all the changes to a branch, test them, and create a PR for the update.
