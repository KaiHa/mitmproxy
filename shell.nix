{ nixpkgs ? import <nixpkgs> {}, compiler ? "default", doBenchmark ? false }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, base, bytestring, cabal-install, connection, data-default
      , haskell-language-server, myhttp-proxy, http-client, http-client-tls, http-conduit
      , http-types, intro, network, optparse-applicative, stdenv, tls, warp
      }:
      mkDerivation {
        pname = "mitmproxy";
        version = "0.1.0.0";
        src = ./.;
        isLibrary = false;
        isExecutable = true;
        buildDepends = [
          cabal-install
          haskell-language-server
        ];
        executableHaskellDepends = [
          base bytestring connection data-default myhttp-proxy http-client http-client-tls
          http-conduit http-types intro network optparse-applicative tls
          warp
        ];
        license = "unknown";
        hydraPlatforms = stdenv.lib.platforms.none;
      };

  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  variant = if doBenchmark then pkgs.haskell.lib.doBenchmark else pkgs.lib.id;

  drv = variant (haskellPackages.callPackage f {});

in

  if pkgs.lib.inNixShell then drv.env else drv
