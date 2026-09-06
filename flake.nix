{
  inputs.rivet-index = {
    url = "tarball+https://pub-661f1abeaa7647bc83e673087e6ff162.r2.dev/v0/indexes/sha256/51735d3da5c6f60b7ec5be7633c02a7858d296268651144a073a210438385205/index.tar.gz";
    flake = false;
  };

  outputs = { self, rivet-index }: {
    lib.resolve = args: import ./resolver.nix (args // { index = rivet-index; });
    publication = builtins.fromJSON (builtins.readFile ./publication.json);
  };
}
