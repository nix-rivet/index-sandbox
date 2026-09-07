{
  outputs = { self }: {
    lib.resolve = args: import ./resolver.nix (args // { routing = builtins.fromJSON (builtins.readFile ./root.json); });
    publication = builtins.fromJSON (builtins.readFile ./publication.json);
  };
}
