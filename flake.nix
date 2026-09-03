{
  inputs.rivet-index = {
    url = "tarball+https://pub-661f1abeaa7647bc83e673087e6ff162.r2.dev/v0/indexes/sha256/ffa55a551ca5fb7c21c8422f3d2f01ef1912fe4f63d558f4458703b5683951ab/index.tar.gz";
    flake = false;
  };

  outputs = { self, rivet-index }: {
    lib.resolve = args: import ./resolver.nix (args // { index = rivet-index; });
    publication = builtins.fromJSON (builtins.readFile ./publication.json);
  };
}
