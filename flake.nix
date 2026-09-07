{
  inputs.rivet-index = {
    url = "tarball+https://pub-661f1abeaa7647bc83e673087e6ff162.r2.dev/v0/indexes/sha256/cd691e2681e60a624482dcad5757d45864c962d6cd71397677114bba63fddef7/index.tar.gz";
    flake = false;
  };

  outputs = { self, rivet-index }: {
    lib.resolve = args: import ./resolver.nix (args // { index = rivet-index; });
    publication = builtins.fromJSON (builtins.readFile ./publication.json);
  };
}
