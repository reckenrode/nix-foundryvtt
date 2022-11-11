{ lib
, callPackage
, stdenv
, coreutils
, findutils
, makeWrapper
, nodejs-18_x
, openssl
, pngout
, requireFile
, unzip
, gzip
, zstd
, brotli
# FIXME: Once nixpkgs-22.11 is out, aarch64-darwin can use pkgsx86_64Darwin to get pngout
, usePngout ? !(stdenv.isDarwin && stdenv.isAarch64)
}:

let
  nodejs = nodejs-18_x;
  foundryvtt-deps = callPackage ./foundryvtt-deps { };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "foundryvtt";
  version = "${finalAttrs.majorVersion}.${finalAttrs.minorVersion}.${finalAttrs.patchVersion}+${finalAttrs.build}";

  majorVersion = "10";
  minorVersion = "0";
  patchVersion = "0";
  build = "290";

  src = requireFile {
    name = "FoundryVTT-${finalAttrs.majorVersion}.${finalAttrs.build}.zip";
    sha256 = "sha256-OGjHsTbFMIRfsT8sZE/vtf1z+T+H2yp5R1MJndv0Vao=";
    url = "https://foundryvtt.com";
  };

  outputs = [ "out" "gzip" "zstd" "brotli" ];

  buildInputs = [ openssl nodejs ];
  nativeBuildInputs = [ coreutils makeWrapper unzip gzip zstd brotli ];

  unpackPhase = "unzip $src";

  dontConfigure = true;

  buildPhase = ''
    rm -rf resources/app/node_modules
  '';

  installPhase =
    let
      node_modules = foundryvtt-deps.nodeDependencies.override {
        inherit (finalAttrs) version;
        src = stdenv.mkDerivation {
          inherit (finalAttrs) src;
          inherit nodejs;
          name = "${finalAttrs.pname}-${finalAttrs.version}-package-json";
          nativeBuildInputs = [ unzip ];
          unpackPhase = "unzip $src resources/app/package.json";
          dontBuild = true;
          installPhase = "mkdir -p $out; cp resources/app/package.json $out;";
        };
      };
    in
    ''
      mkdir -p $out $out/bin $out/libexec
      cp -R resources/app/* $out
      ln -s ${lib.getLib node_modules}/lib/node_modules $out/node_modules
      echo "#!/bin/sh" > $out/libexec/${finalAttrs.pname}
      echo "${lib.getBin nodejs}/bin/node $out/main.js \"\$@\"" >> $out/libexec/${finalAttrs.pname}
      chmod a+x $out/libexec/${finalAttrs.pname}
      makeWrapper $out/libexec/${finalAttrs.pname} $out/bin/${finalAttrs.pname} \
        --prefix PATH : "${lib.getBin openssl}/bin"

      # Run PNG images through `pngout` if it’s available.
      ${if usePngout then ''
        find $out/public -name '*.png' -exec ${pngout}/bin/pngout {} -k1 -y \;
      '' else ""}

      # Precompress assets for use with e.g., Caddy
      for method in gzip zstd brotli; do
        mkdir -p ''${!method}
        cp -R resources/app/public/* ''${!method}
        find ''${!method} -name '*.png' -delete -or -name '*.jpg' -delete \
          -or -name '*.webp' -delete -or -name '*.wav' -delete -or -name '*.ico' -delete \
          -or -name '*.icns' -delete
      done

      find $gzip -type f -exec gzip -9 {} +
      find $zstd -type f -exec zstd -19 --rm {} +
      find $brotli -type f -exec brotli -9 --rm {} +
    '';

  meta = {
    homepage = "https://foundryvtt.com";
    description = "A self-hosted, modern, and developer-friendly roleplaying platform.";
    #license = lib.licenses.unfree;
    platforms = lib.lists.intersectLists nodejs.meta.platforms openssl.meta.platforms;
  };
})
