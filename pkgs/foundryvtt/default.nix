{
  lib,
  buildPackages,
  unzip,
  requireFile,
  openssl,
  makeWrapper,
  gzip,
  zstd,
  brotli,
  pngout,
  stdenv,
  writeScript,
  nodejs,
  usePngout ? true,
}:

let
  foundry-version-hashes = lib.importJSON ./versions.json;

  resolveVersion =
    attrs:
    if attrs ? version then
      let
        inherit (attrs) version;

        versionParts = lib.versions.splitVersion version;
        major = if lib.head versionParts == "0" then lib.versions.minor version else lib.head versionParts;
        build = lib.last versionParts;
        name = "${major}.${build}";
      in
      {
        inherit name;
        value =
          foundry-version-hashes.${name}
            or (builtins.abort "Unknow  n FoundryVTT version: '${attrs.version}'. Please run the update script.");
      }
    else if (attrs.majorVersion or null) == null then
      lib.warn
        "Using `default` or the unversioned `foundryvtt` attribute without specifying a major version is deprecated. It will always default to FoundryVTT v11. Specify a `majorVersion` or use one of the versioned attributes."
        (resolveVersion (attrs // { majorVersion = "11"; }))
    else if (attrs.build or null) != null then
      let
        inherit (attrs) build;
        resolved = lib.pipe foundry-version-hashes [
          lib.attrsToList
          (lib.filter (versionInfo: lib.versions.minor versionInfo.name == build))
        ];
      in
      if lib.length resolved > 0 then
        lib.last resolved
      else
        builtins.abort "Unknown FoundryVTT build: '${build}'. Please run the update script."
    else
      let
        inherit (attrs) majorVersion;
        releaseType = lib.toLower (attrs.releaseType or "stable");

        isReleaseTypeAndMajor =
          versionInfo:
          releaseAtLeast releaseType versionInfo.value.releaseType
          && lib.versions.major versionInfo.name == majorVersion;

        resolved = lib.pipe foundry-version-hashes [
          lib.attrsToList
          (lib.filter isReleaseTypeAndMajor)
          (lib.sort (lhs: rhs: lhs.name < rhs.name))
        ];
      in
      if lib.length resolved > 0 then
        lib.last resolved
      else
        builtins.abort "Unknown FoundryVTT major version: '${majorVersion}'. Please run the update script.";

  prioritiesMap =
    lib.pipe
      [
        "prototype"
        "development"
        "testing"
        "stable"
      ]
      [
        (lib.imap0 (lib.flip lib.nameValuePair))
        lib.listToAttrs
      ];

  releaseAtLeast =
    releaseType: release:
    let
      typePriority = prioritiesMap.${releaseType};
      releasePriority = prioritiesMap.${release};
    in
    releasePriority >= typePriority;

  # Needed to make `buildNpmPackage` work with how the FoundryVTT zip is structured.
  buildNpmPackage = buildPackages.buildNpmPackage.override { inherit fetchNpmDeps; };

  fetchNpmDeps =
    args:
    buildPackages.fetchNpmDeps (
      args
      // {
        buildInputs = [ unzip ];
        setSourceRoot = ''
          if [[ "$curSrc" =~ FoundryVTT-.*.zip$ ]]; then
            sourceRoot=$(pwd)/resources/app
          fi
        '';
      }
    );

  foundryPkg =
    attrs:
    let
      inherit (attrs) resolvedVersion;
      finalAttrs = removeAttrs attrs [ "resolvedVersion" ];
      shortVersion = resolvedVersion.name;
    in
    buildNpmPackage {
      inherit (finalAttrs) pname version;

      src = requireFile {
        name = "FoundryVTT-${shortVersion}.zip";
        inherit (resolvedVersion.value) hash;
        url = "https://foundryvtt.com";
      };

      postPatch = ''
        install -m644 "${./deps/package-lock-${shortVersion}.json}" "$sourceRoot/package-lock.json"
      '';

      outputs = [
        "out"
        "gzip"
        "zstd"
        "brotli"
      ];

      buildInputs = [ openssl ];
      nativeBuildInputs = [
        makeWrapper
        unzip
        gzip
        zstd
        brotli
      ];

      setSourceRoot = "sourceRoot=$(pwd)/resources/app";

      makeCacheWritable = true;
      inherit (resolvedVersion.value) npmDepsHash;

      dontNpmBuild = true;

      postInstall = ''
        foundryvtt=$out/lib/node_modules/foundryvtt

        mkdir -p "$out/bin" "$out/libexec"

        ln -s "$foundryvtt/main.js" "$out/libexec/foundryvtt"
        chmod a+x "$out/libexec/foundryvtt"

        makeWrapper "$out/libexec/foundryvtt" "$out/bin/foundryvtt" \
          --prefix PATH : "${lib.getBin openssl}/bin"

        ln -s "$foundryvtt/public" "$out/public"

        # Run PNG images through `pngout` if it’s available.
        ${
          if usePngout then
            ''
              find $foundryvtt/public -name '*.png' -exec ${pngout}/bin/pngout {} -k1 -y \;
            ''
          else
            ""
        }

        # Precompress assets for use with e.g., Caddy
        for method in gzip zstd brotli; do
          mkdir -p ''${!method}
          cp -R "$foundryvtt/public/"* ''${!method}
          find ''${!method} -name '*.png' -delete -or -name '*.jpg' -delete \
            -or -name '*.webp' -delete -or -name '*.wav' -delete -or -name '*.ico' -delete \
            -or -name '*.icns' -delete
        done

        find "$gzip" -type f -exec gzip -9 {} +
        find "$zstd" -type f -exec zstd -19 --rm {} +
        find "$brotli" -type f -exec brotli -9 --rm {} +
      '';
    };

  formatVersion =
    attrs:
    let
      inherit (attrs) majorVersion build;

      olderMap = {
        "32" = "0.1.5";
        "33" = "0.1.6";
        "34" = "0.1.7";
        "35" = "0.2.0";
        "36" = "0.2.1";
        "37" = "0.2.2";
        "38" = "0.2.3";
        "39" = "0.2.4";
        "40" = "0.2.5";
        "41" = "0.2.6";
        "42" = "0.2.7";
        "43" = "0.2.8";
        "44" = "0.2.9";
        "45" = "0.3.0";
        "46" = "0.3.1";
        "47" = "0.3.2";
        "48" = "0.3.3";
        "49" = "0.3.4";
        "50" = "0.3.5";
        "51" = "0.3.6";
        "52" = "0.3.7";
        "53" = "0.3.8";
        "54" = "0.3.9";
        "55" = "0.4.0";
        "56" = "0.4.1";
        "57" = "0.4.2";
        "58" = "0.4.3";
        "59" = "0.4.4";
        "60" = "0.4.5";
        "61" = "0.4.6";
        "62" = "0.4.7";
        "63" = "0.5.0";
        "64" = "0.5.1";
        "65" = "0.5.2";
        "66" = "0.5.3";
        "67" = "0.5.4";
        "68" = "0.5.5";
        "69" = "0.5.6";
        "70" = "0.5.7";
        "71" = "0.6.0";
        "72" = "0.6.1";
        "73" = "0.6.2";
        "74" = "0.6.3";
        "75" = "0.6.4";
        "76" = "0.6.5";
        "79" = "0.6.6";
        "77" = "0.7.0";
        "78" = "0.7.1";
        "80" = "0.7.2";
        "81" = "0.7.3";
        "82" = "0.7.4";
        "83" = "0.7.5";
        "84" = "0.7.6";
        "85" = "0.7.7";
        "86" = "0.7.8";
        "87" = "0.7.9";
        "94" = "0.7.10";
        "88" = "0.8.0";
        "89" = "0.8.1";
        "90" = "0.8.2";
        "91" = "0.8.3";
        "92" = "0.8.4";
        "93" = "0.8.5";
        "95" = "0.8.6";
        "97" = "0.8.7";
        "101" = "0.8.8";
        "102" = "0.8.9";
      };
      mappedVersion = olderMap.${build} or "${majorVersion}.0.0";
    in
    "${mappedVersion}+${build}";
in
stdenv.mkDerivation (
  finalAttrs:
  let
    resolvedVersion = resolveVersion finalAttrs;
    majorVersion = lib.versions.major resolvedVersion.name;
    build = lib.versions.minor resolvedVersion.name;
    version = finalAttrs.version or (formatVersion { inherit majorVersion build; });
  in
  {
    name = "foundryvtt-${version}";

    outputs = [
      "out"
      "gzip"
      "zstd"
      "brotli"
    ];

    buildCommand =
      let
        foundryvtt = foundryPkg {
          pname = lib.getName finalAttrs;
          version = lib.getVersion finalAttrs;
          inherit resolvedVersion;
        };
      in
      ''
        ln -s "${foundryvtt.outPath}" "$out"
        ln -s "${foundryvtt.gzip}" "$gzip"
        ln -s "${foundryvtt.zstd}" "$zstd"
        ln -s "${foundryvtt.brotli}" "$brotli"
      '';

    passthru.updateScript = writeScript "update-foundryvtt" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p coreutils gnused jq moreutils nodejs prefetch-npm-deps unzip
      set -eu -o pipefail

      src=''${src:-$1}

      shortVersion=$(basename "$src" | sed 's|.*-\([0-9][0-9]*\.[0-9][0-9]*\).zip|\1|')
      version="''${shortVersion%%.*}.0.0+''${shortVersion#*.}"

      foundrySrc=$(mktemp -d)
      trap 'rm -rf -- "$foundrySrc"' EXIT

      unzip -q "$src" -d "$foundrySrc"

      # Generate package-lock.json for the requested version
      pushd "$foundrySrc/resources/app" > /dev/null
      sed \
        -e 's|"@foundryvtt/pdfjs": "2.14.305"|"@foundryvtt/pdfjs": "foundryvtt/pdfjs#d9c4a6ee44512a094bc7395aa0ba7fe9be9a8375"|' \
        -e 's|"@foundryvtt/pdfjs": "2.14.305-1"|"@foundryvtt/pdfjs": "foundryvtt/pdfjs#2196ae9bcbd8d6a9b0b9c493d0e9f3aca13f2fd9"|' \
        -e 's|"@foundryvtt/pdfjs": "\([0-9.-]*\)"|"@foundryvtt/pdfjs": "foundryvtt/pdfjs#v\1"|' \
        -e 's|"pixi.js": "^\([0-9.-]*\)"|"pixi.js": "~\1"|' \
        -i package.json
      npm update
      sed \
        -e 's|"@foundryvtt/pdfjs": "foundryvtt/pdfjs#d9c4a6ee44512a094bc7395aa0ba7fe9be9a8375"|"@foundryvtt/pdfjs": "2.14.305"|' \
        -e 's|"@foundryvtt/pdfjs": "foundryvtt/pdfjs#2196ae9bcbd8d6a9b0b9c493d0e9f3aca13f2fd9"|"@foundryvtt/pdfjs": "2.14.305-1"|' \
        -e 's|"@foundryvtt/pdfjs": "foundryvtt/pdfjs#v\([^"]*\)"|"@foundryvtt/pdfjs": "\1"|' \
        -e 's|"pixi.js": "~\([0-9.-]*\)"|"pixi.js": "^\1"|' \
        -i package-lock.json
      popd

      cp "$foundrySrc/resources/app/package-lock.json" "./pkgs/foundryvtt/deps/package-lock-$shortVersion.json"

      hash=$(nix hash file "$src")
      npmsDepsHash=$(prefetch-npm-deps "$foundrySrc/resources/app/package-lock.json")
      releaseType=''${2:-$(jq -r ".\"$shortVersion\".releaseType" pkgs/foundryvtt/versions.json)}

      versionJson="{\"$shortVersion\": { \"hash\": \"$hash\", \"npmDepsHash\": \"$npmsDepsHash\", \"releaseType\": \"$releaseType\" }}"
      jq -S ". * $versionJson" ./pkgs/foundryvtt/versions.json \
        | sponge ./pkgs/foundryvtt/versions.json
    '';

    meta = {
      homepage = "https://foundryvtt.com";
      description = "A self-hosted, modern, and developer-friendly roleplaying platform.";
      #license = lib.licenses.unfree;
      platforms = lib.lists.intersectLists nodejs.meta.platforms openssl.meta.platforms;
    };
  }
)
