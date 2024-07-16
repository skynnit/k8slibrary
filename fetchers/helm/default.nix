{ stdenv, cacert, kubernetes-helm }:

{ repo, chart, version, hash }:

stdenv.mkDerivation rec{
  name = "${repo.name}-${chart}-${version}.tgz";
  builder = ./builder.sh;
  nativeBuildInputs = [ cacert kubernetes-helm ];

  outputHashMode = "flat";
  outputHashAlgo = "sha256";
  outputHash = hash;

  repoName = repo.name;
  repoUrl = repo.url;

  inherit chart version;
}
