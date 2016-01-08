{ mkDerivation, base, cond, containers, directory, errors
, exceptions, filepath, free, hspec, mtl, QuickCheck, stdenv
, strict, text, transformers
}:
mkDerivation {
  pname = "gpio";
  version = "0.5.1";
  src = ./.;
  libraryHaskellDepends = [
    base cond containers directory errors exceptions filepath free mtl
    QuickCheck strict text transformers
  ];
  testHaskellDepends = [
    base cond containers directory errors exceptions filepath free
    hspec mtl QuickCheck strict text transformers
  ];
  homepage = "https://github.com/dhess/gpio";
  description = "Control GPIO pins";
  license = stdenv.lib.licenses.bsd3;
}
