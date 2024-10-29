{
  stdenv,
  fetchHelm,
  kubernetes-helm,
  writeText,
  yq-go,
  php,
  k8sapi,
  kubernetes,
  helm ? {},
  deployName,
  deployNamespace,
  kubernetes-version,
  values ? {}
}:
let
  yamlPHP = 
    php.withExtensions ({ enabled, all }:
      enabled ++ [ all.yaml ]);
in
stdenv.mkDerivation rec{
  pname = helm.chartName;
  version = helm.chartVersion;

  src = fetchHelm {
    repo = {
      name = helm.repoName;
      url = helm.repoUrl;
    };
    chart = helm.chartName;
    inherit version;
    hash = helm.chartHash;
  };

  nativeBuildInputs = [ kubernetes-helm yq-go ];

  unpackPhase = ''
    mkdir ./templated
    helm template \
      --include-crds \
      --no-hooks \
      --namespace ${deployNamespace} \
      -f ${writeText "${pname}-values.json" (builtins.toJSON values)} \
      --kube-version ${kubernetes-version} \
      --output-dir ./templated \
      ${helm.chartName} \
      $src
  '';

  buildPhase = ''
    yq -o json -s '.kind + "_" + .metadata.name + ".json"' templated/${helm.chartName}/templates/*.yaml
    cp *.json templated
    ${yamlPHP}/bin/php ${../../swag.php} ${deployName} ./templated ${k8sapi} > enriched.json
  '';

  installPhase = ''
    mkdir -p $out
    cp enriched.json $out
    cp -r ./templated $out
  '';
}
