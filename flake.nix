{
  inputs.rivet-index = {
    url = "tarball+https://pub-661f1abeaa7647bc83e673087e6ff162.r2.dev/v0/indexes/sha256/825bc179fcd32461577da94f328202f2cc221ad1ac792e81c4d067e7cfd3d0e9/index.tar.gz";
    flake = false;
  };

  outputs = { self, rivet-index }: {
    lib.resolve = args: import ./resolver.nix (args // { index = rivet-index; });
    publication = builtins.fromJSON (builtins.readFile ./publication.json);
  };
}
