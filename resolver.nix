{
  index ? null,
  routing ? null,
  layout ? "balanced",
  package,
  version,
  attribute ? null,
  coordinatePolicy ? "latest",
}:

let
  fail = message: throw "Nix Rivet v0: ${message}";
  requireString = name: value:
    if builtins.isString value && value != "" then value else fail "${name} must be a non-empty string";
  requestedPackage = requireString "package" package;
  requestedVersion = requireString "version" version;
  requestedAttribute =
    if attribute == null then null else requireString "attribute" attribute;
  recursive = routing != null && routing ? recursive;
  routeKey = builtins.hashString "sha256" requestedPackage + builtins.hashString "sha256" requestedVersion;
  fetchNode = descriptor:
    let path = builtins.fetchTarball {
      url = "${routing.recursive.base_url}/v1/nodes/sha256/${descriptor.sha256}/node.tar.gz";
      sha256 = descriptor.nar_hash;
    }; in builtins.fromJSON (builtins.readFile (path + "/node.json"));
  walk = depth: previousOffset: descriptor:
    let node = fetchNode descriptor; in
    if depth > 128 || node.schema != "nix-rivet.recursive-node/v1" then fail "invalid recursive index node or excessive depth"
    else if node.kind == "leaf" then node
    else if node.kind != "branch" || !builtins.isInt node.offset || node.offset <= previousOffset || node.offset >= 128 then
      fail "invalid recursive routing offset"
    else let digit = builtins.substring node.offset 1 routeKey; in
      if !(builtins.hasAttr digit node.children) then fail "package/version was not found in the indexed corpus"
      else walk (depth + 1) node.offset node.children.${digit};
  leaf = walk 1 (-1) routing.recursive.root;
  selectedIndex = if recursive then builtins.fetchTarball {
    url = builtins.replaceStrings [ "tarball+" ] [ "" ] routing.index.url;
    sha256 = routing.recursive.fat_nar_hash;
  } else index;
  _layout = if builtins.elem layout [ "balanced" "fat" ] then true else fail "layout must be balanced or fat";
  root = if recursive && layout == "balanced" then leaf.manifest
    else builtins.fromJSON (builtins.readFile (selectedIndex + "/manifest.json"));
  _schema =
    if builtins.elem root.schema [ "nix-rivet.index/v0" "nix-rivet.index/v1" ] then true else fail "unsupported index schema";
  _policy =
    if !(builtins.elem coordinatePolicy [ "earliest" "latest" ]) then
      fail "coordinatePolicy must be earliest or latest"
    else if coordinatePolicy == "earliest" && root.schema == "nix-rivet.index/v0" then
      fail "earliest requires a history-aware index; this v0 index retains only latest observations"
    else true;
  _system =
    if root.system == "x86_64-linux" then true else fail "unsupported index system";
  bucketName = builtins.substring 0 2 (builtins.hashString "sha256" requestedPackage);
  bucketPath = selectedIndex + "/buckets/${bucketName}.json";
  bucket =
    if recursive && layout == "balanced" then leaf.packages
    else if builtins.pathExists bucketPath then
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
  first = if selected ? f then selected.f else fail "history-aware candidate is missing its earliest release";
  validIndex = value: builtins.isInt value && value >= 0 && value < builtins.length root.releases;
  _endpoints =
    if !(validIndex selected.r) then fail "candidate has an invalid latest release"
    else if root.schema == "nix-rivet.index/v1" && (!(validIndex first) || first > selected.r) then
      fail "candidate has invalid release endpoints"
    else true;
  release = builtins.elemAt root.releases (if coordinatePolicy == "earliest" then first else selected.r);
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
assert _layout;
assert _schema;
assert _system;
assert _policy;
assert _endpoints;
{
  coordinate = {
    channel = root.channel;
    system = root.system;
    inherit (release) revision;
    release = release.id;
    attribute = attributeText selected;
    package = requestedPackage;
    version = requestedVersion;
    inherit coordinatePolicy;
  };
  inherit evaluatedVersion;
  derivation =
    if evaluatedVersion != requestedVersion then
      fail "evaluated version ${builtins.toJSON evaluatedVersion} does not match requested version ${builtins.toJSON requestedVersion}"
    else
      derivation;
}
