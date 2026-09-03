{
  index,
  package,
  version,
  attribute ? null,
}:

let
  fail = message: throw "Nix Rivet v0: ${message}";
  requireString = name: value:
    if builtins.isString value && value != "" then value else fail "${name} must be a non-empty string";
  requestedPackage = requireString "package" package;
  requestedVersion = requireString "version" version;
  requestedAttribute =
    if attribute == null then null else requireString "attribute" attribute;
  root = builtins.fromJSON (builtins.readFile (index + "/manifest.json"));
  _schema =
    if root.schema == "nix-rivet.index/v0" then true else fail "unsupported index schema";
  _system =
    if root.system == "x86_64-linux" then true else fail "unsupported index system";
  bucketName = builtins.substring 0 2 (builtins.hashString "sha256" requestedPackage);
  bucketPath = index + "/buckets/${bucketName}.json";
  bucket =
    if builtins.pathExists bucketPath then
      builtins.fromJSON (builtins.readFile bucketPath)
    else
      fail "index bucket ${bucketName} is missing";
  versions =
    if builtins.hasAttr requestedPackage bucket then
      builtins.getAttr requestedPackage bucket
    else
      fail "package ${builtins.toJSON requestedPackage} was not found";
  candidates =
    if builtins.hasAttr requestedVersion versions then
      builtins.getAttr requestedVersion versions
    else
      fail "version ${builtins.toJSON requestedVersion} was not found for package ${builtins.toJSON requestedPackage}";
  attributeText = candidate: candidate.n;
  qualified =
    if requestedAttribute == null then
      candidates
    else
      builtins.filter (candidate: attributeText candidate == requestedAttribute) candidates;
  candidateList = builtins.concatStringsSep ", " (map attributeText candidates);
  selected =
    if builtins.length qualified == 1 then
      builtins.head qualified
    else if requestedAttribute != null && qualified == [ ] then
      fail "attribute ${builtins.toJSON requestedAttribute} is not a candidate; candidates: ${candidateList}"
    else
      fail "resolution is ambiguous; specify one exact attribute from: ${candidateList}";
  release = builtins.elemAt root.releases selected.r;
  source = builtins.fetchTarball {
    url = release.source.url;
    sha256 = release.source.nar_hash;
  };
  packageSet = import source {
    system = root.system;
    config = import (source + "/pkgs/top-level/packages-config.nix");
  };
  derivation = builtins.foldl' (
    scope: name:
    if builtins.hasAttr name scope then
      builtins.getAttr name scope
    else
      fail "recorded attribute ${builtins.toJSON (attributeText selected)} is absent at revision ${release.revision}"
  ) packageSet selected.a;
  evaluatedVersion =
    if derivation ? version && builtins.isString derivation.version then
      derivation.version
    else
      fail "recorded attribute ${builtins.toJSON (attributeText selected)} has no string version";
in
assert _schema;
assert _system;
{
  coordinate = {
    channel = root.channel;
    system = root.system;
    inherit (release) revision;
    release = release.id;
    attribute = attributeText selected;
    package = requestedPackage;
    version = requestedVersion;
  };
  inherit evaluatedVersion;
  derivation =
    if evaluatedVersion != requestedVersion then
      fail "evaluated version ${builtins.toJSON evaluatedVersion} does not match requested version ${builtins.toJSON requestedVersion}"
    else
      derivation;
}
