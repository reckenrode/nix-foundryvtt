# nix-foundryvtt

This is repo packages FoundryVTT for use with NixOS and Nix. It only includes the server component.
We use FoundryVTT intermitently, but I’ve subscribed to notifications on foundryvtt/foundryvtt in
the hope I can do a better job keeping up to date with releases when we’re not actively playing.

The NixOS module targets the latest release of NixOS. That’s 22.05. Once 22.11 is released, it will
be updated for NixOS 22.11 if necessary. This should probably be upstreamed into nixpkgs eventually.

## Performing a Foundry Upgrade

This repo packages only a single release of FoundryVTT; typically the most up-to-date version.  When Foundry releases a new version, here's a procedure for upgrading to the latest release.

1. Download the new Linux/NodeJS version of Foundry from your licensed account at https://foundryvtt.com/

2. Run `nix-prefetch-url` to load the zip file into your Nix store, outputting its sha256 hash; eg. `nix-prefetch-url --type sha256 file:///home/my-user/Downloads/FoundryVTT-11.304.zip`.

3. Update `pkgs/default.nix`, correcting the `majorVersion` and `build` to the new released version.  Update `sha256` to the output from step #2.

4. Unzip the FoundryVTT-N.M.zip file into a temporary directory.

5. In the temporary directory, edit `resources/app/package.json`.
    - Find the version of "@foundryvtt/pdfjs" referenced in the dependencies; eg. 3.4.120.
    - Go to https://github.com/foundryvtt/pdfjs and find the corresponding commit hash for that version; eg. https://github.com/foundryvtt/pdfjs/commit/d5a3072cd65faf5e5261de1de75ec7d7dab1a778 says "Update pdf.js version 3.4.120", so d5a3072cd65faf5e5261de1de75ec7d7dab1a778 is the commit hash.
    - Change the dependency referenced in package.json to `git+https://github.com/foundryvtt/pdfjs.git#d5a3072cd65faf5e5261de1de75ec7d7dab1a778`, with the found commit hash.

6. Run `node2nix` in `pkgs/foundryvtt/foundryvtt-deps` of this repo; eg.
    ```
    nix-shell -p node2nix
    node2nix -i ~/foundry-tmp-directory/resources/app/package.json -18
    ```

7. Commit all the changes to a branch, test them, and create a PR for the update.
