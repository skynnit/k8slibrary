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
  version = "2.13.3";

  src = fetchFromGitHub {
    owner = "argoproj";
    repo = "argo-cd";
    rev = "v${version}";
    hash = "sha256-1z3tTXHVJ3e3g+DAoEGb8P6e4iEe1tiaM+7IPyuQp7U=";
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
