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

  foundry-version-hashes = version: {
    "10.291" = "0j9xjqqpl8maggi45wskajxl2c9jlcl8pw1cx6nmgbcj5w4c5xrf";
    "11.301" = "1r5bqhd3cfq3yvzb1yybgvysbhbjqv6d2f768b063fdsdq2ixi2s";
    "11.302" = "1myhhfxm0qa40ymx3gznwmh0xwl2kymqcgz777dks42j2wdy1zci";
    "11.304" = "1mgz80927csdmarizpmja13kph2vsqns4mbzncbkz2lrc5xlicbm";
    "11.305" = "1m2zsw9ypah109qj6nkfh3aa13n35mbh2v5g4r26vsbx3mk8azy4";
    "11.306" = "15a5pxc37rv898gn5d1f8dv59j57r3nxqdw10mj4c5cbjly438x0";
    "11.307" = "0k5qkmf1kk01227ads3bh7bgkrvjhjhjbwp6hkl58zdm166dikah";
    "11.308" = "04jckd3i81a3jdq86cqp7s6b3gpsx9d1q8sbcca4fzk37yr2c53c";
    "11.309" = "1n1dnm3jpkziag6pb502m8s9qlafsv5p6yxijfvh4khmp7wjkzra";
  }.${version} or (
    lib.warn "Unknown foundryvtt version: '${version}'. Please update foundry-version-hashes." lib.fakeHash
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "foundryvtt";
  version = "${finalAttrs.majorVersion}.${finalAttrs.minorVersion}.${finalAttrs.patchVersion}+${finalAttrs.build}";

  majorVersion = "11";
  minorVersion = "0";
  patchVersion = "0";
  build = "309";

  src = requireFile {
    name = "FoundryVTT-${finalAttrs.majorVersion}.${finalAttrs.build}.zip";
    sha256 = foundry-version-hashes "${finalAttrs.majorVersion}.${finalAttrs.build}";
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
