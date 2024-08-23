{
  stdenv,
  fetchurl,
  php,
  k8sapi,
  deployName ? "argocd",
  deployNamespace ? "argocd"
}:

let
  yamlPHP = 
    php.withExtensions ({ enabled, all }:
      enabled ++ [ all.yaml ]);
in
stdenv.mkDerivation rec{
  pname = "argocd";
  version = "2.12.2";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/argoproj/argo-cd/v${version}/manifests/install.yaml";
    hash = "sha256-zlOZMl7xSNPMFr4ycO+S08fgXJreVfs1ZaprysjL+cU=";
  };

  unpackPhase = ''
    mkdir templated
    cp $src templated
  '';

  buildPhase = ''
    ${yamlPHP}/bin/php ${../../swag.php} ${deployName} templated/ ${k8sapi} > enriched.json
  '';

  installPhase = ''
    mkdir -p $out
    cp -r templated $out
    cp enriched.json $out
  '';
}
