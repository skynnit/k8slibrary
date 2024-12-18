{
  stdenv,
  fetchFromGitHub,
  php,
  kubernetes-helm,
  yq-go,
  k8sapi,
  writeText,
  deployName ? "argocd",
  deployNamespace ? "argocd",
  kubernetes-version ? "1.28.0",
  values ? {}
}:

let
  yamlPHP = 
    php.withExtensions ({ enabled, all }:
      enabled ++ [ all.yaml ]);
in
stdenv.mkDerivation rec{
  pname = "argocd";
  version = "2.13.1";

  src = fetchFromGitHub {
    owner = "argoproj";
    repo = "argo-cd";
    rev = "v${version}";
    hash = "sha256-0qL9CnEwEp7sJK7u6EKHVFY/hH8lTb182HZ3r+9nIyQ=";
  };

  nativeBuildInputs = [ yq-go ];

  buildPhase = ''
    mkdir templated
    cp manifests/ha/namespace-install.yaml templated
    cp manifests/crds/*.yaml templated
    rm templated/kustomization.yaml
    yq -o json -s '.kind + "_" + .metadata.name + ".json"' templated/*.yaml
    cp *.json templated
    ${yamlPHP}/bin/php ${../../swag.php} ${deployName} templated/ ${k8sapi} > enriched.json
  '';

  installPhase = ''
    mkdir -p $out
    cp -r templated $out
    cp enriched.json $out
  '';
}
