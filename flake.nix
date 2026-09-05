{
  inputs.rivet-index = {
    url = "tarball+https://pub-661f1abeaa7647bc83e673087e6ff162.r2.dev/v0/indexes/sha256/30628174379f63edd2a1fa1269d53208eb0ed664fe3641defeec1fbac4703104/index.tar.gz";
    flake = false;
  };

  outputs = { self, rivet-index }: {
    lib.resolve = args: import ./resolver.nix (args // { index = rivet-index; });
    publication = builtins.fromJSON (builtins.readFile ./publication.json);
  };
}
