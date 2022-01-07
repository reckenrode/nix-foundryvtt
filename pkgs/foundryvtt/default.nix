{ lib
, stdenv
, coreutils
, makeWrapper
, nodejs
, openssl
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
  build = "241";

  src = requireFile {
    name = "FoundryVTT-${majorVersion}.${build}.zip";
    sha256 = "sha256-7B0fv3e3VbEfX9s6PPRozPXF5lE9c92FYWqMeqeYWxI=";
    url = "https://foundryvtt.com";
  };

  buildInputs = [ openssl nodejs ];
  nativeBuildInputs = [ coreutils makeWrapper unzip ];

  unpackPhase = "unzip $src";

  dontConfigure = true;

  buildPhase = ''
    rm -rf resources/app/node_modules
  '';

  installPhase =
    let
      node_modules = foundryvtt-deps.nodeDependencies.override {
        inherit version;
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
      echo "${nodejs}/bin/node $out/main.js \"\$@\"" >> $out/libexec/${pname}
      chmod a+x $out/libexec/${pname}
      makeWrapper $out/libexec/${pname} $out/bin/${pname} --prefix PATH : "${openssl}/bin"
    '';

  meta = {
    homepage = "https://foundryvtt.com";
    description = "A self-hosted, modern, and developer-friendly roleplaying platform.";
    #license = lib.licenses.unfree;
    platforms = lib.lists.intersectLists nodejs.meta.platforms openssl.meta.platforms;
  };
}
