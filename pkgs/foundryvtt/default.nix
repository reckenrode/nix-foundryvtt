{ lib
, stdenv
, coreutils
, findutils
, makeWrapper
, nodejs-14_x
, openssl
, pngout ? null
, requireFile
, unzip
, foundryvtt-deps
, gzip
, zstd
, brotli
}:

stdenv.mkDerivation rec {
  pname = "foundryvtt";
  version = "${majorVersion}.${minorVersion}.${patchVersion}+${build}";

  majorVersion = "9";
  minorVersion = "0";
  patchVersion = "0";
  build = "269";

  src = requireFile {
    name = "FoundryVTT-${majorVersion}.${build}.zip";
    sha256 = "sha256-e8GXQeDXz2l48S754hxEyOXS3goeasXqUrOQ4M3QD5s=";
    url = "https://foundryvtt.com";
  };

  outputs = [ "out" "gzip" "zstd" "brotli" ];

  buildInputs = [ openssl nodejs-14_x ];
  nativeBuildInputs = [ coreutils makeWrapper unzip gzip zstd brotli ];

  unpackPhase = "unzip $src";

  dontConfigure = true;

  buildPhase = ''
    rm -rf resources/app/node_modules
  '';

  installPhase =
    let
      node_modules = foundryvtt-deps.nodeDependencies.override {
        inherit version;
        nodejs = nodejs-14_x;
        src = stdenv.mkDerivation {
          inherit src;
          name = "${pname}-${version}-package-json";
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
      ln -s ${node_modules}/lib/node_modules $out/node_modules
      echo "#!/bin/sh" > $out/libexec/${pname}
      echo "${nodejs-14_x}/bin/node $out/main.js \"\$@\"" >> $out/libexec/${pname}
      chmod a+x $out/libexec/${pname}
      makeWrapper $out/libexec/${pname} $out/bin/${pname} --prefix PATH : "${openssl}/bin"

      # Run PNG images through `pngout` if it’s available.
      ${if pngout != null then ''
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
    platforms = lib.lists.intersectLists nodejs-14_x.meta.platforms openssl.meta.platforms;
  };
}
