{ lib
, stdenv
, coreutils
, makeWrapper
, nodejs
, openssl
, requireFile
, unzip
}:

stdenv.mkDerivation rec {
  name = "foundryvtt";
  version = "0.7.9";

  src = requireFile {
    name = "${name}-${version}.zip";
    sha256 = "672706c3512be90e6d64dc9c9769e78dad1d1daf6b9c510c65ca4c7e0d2f2e53";
    url = "https://foundryvtt.com";
  };

  buildInputs = [ openssl nodejs ];

  nativeBuildInputs = [ coreutils makeWrapper unzip ];

  unpackPhase = "unzip $src";

  installPhase = ''
    mkdir -p $out $out/bin $out/libexec
    cp -r resources/app/* $out
    echo "#!/bin/sh" > $out/libexec/${name}
    echo "${nodejs}/bin/node $out/main.js \"\$@\"" >> $out/libexec/${name}
    chmod a+x $out/libexec/${name}
    makeWrapper $out/libexec/${name} $out/bin/${name} --prefix PATH : "${openssl}/bin"
  '';

  meta = with stdenv.lib; {
    homepage = "https://foundryvtt.com";
    description = "A self-hosted, modern, and developer-friendly roleplaying platform.";
#    license = licenses.unfree;
    platforms = lib.lists.intersectLists nodejs.meta.platforms openssl.meta.platforms;
  };
}
