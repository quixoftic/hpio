{ mkDerivation, async, base, bytestring, containers, directory
, exceptions, filepath, free, hspec, inline-c, mtl
, optparse-applicative, QuickCheck, stdenv, text, transformers
, unix, unix-bytestring
}:
mkDerivation {
  pname = "gpio";
  version = "0.5.1";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    base bytestring containers directory exceptions filepath free
    inline-c mtl QuickCheck text transformers unix unix-bytestring
  ];
  executableHaskellDepends = [
    async base mtl optparse-applicative transformers
  ];
  testHaskellDepends = [
    base bytestring containers directory exceptions filepath free hspec
    inline-c mtl QuickCheck text transformers unix unix-bytestring
  ];
  homepage = "https://github.com/dhess/gpio";
  description = "Monads for GPIO in Haskell";
  license = stdenv.lib.licenses.bsd3;
}
