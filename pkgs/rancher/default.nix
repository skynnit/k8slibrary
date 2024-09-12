{
  stdenv,
  fetchHelm,
  kubernetes-helm,
  writeText,
  yq-go,
  php,
  k8sapi,
  deployName ? "rancher",
  deployNamespace ? "cattle-system",
  kubernetes-version ? "1.28.0",
  values ? {},
  patchFunctions ? []
}:

let
  yamlPHP = 
    php.withExtensions ({ enabled, all }:
      enabled ++ [ all.yaml ]);
in
stdenv.mkDerivation rec{
  pname = "rancher";
  version = "2.9.1";

  src = fetchHelm {
    repo = {
      name = "rancher-stable";
      url = "https://releases.rancher.com/server-charts/stable";
    };
    chart = "rancher";
    inherit version;
    hash = "sha256-ipq+2pBDiwpLXTVd/QoIBfXnfnsfXzNzB+6uSmUMfAg=";
  };

  nativeBuildInputs = [ kubernetes-helm yq-go ];

  unpackPhase = ''
    mkdir ./templated
    helm template \
      --namespace ${deployNamespace} \
      -f ${writeText "${pname}-values.json" (builtins.toJSON values)} \
      --kube-version ${kubernetes-version} \
      --output-dir ./templated \
      rancher \
      $src
  '';

  buildPhase = ''
    yq -o json -s '.kind + "_" + .metadata.name' templated/rancher/templates/*.yaml
    cp *.json templated
    ${yamlPHP}/bin/php ${../../swag.php} ${deployName} ./templated ${k8sapi} > enriched.json
  '';

  installPhase = ''
    mkdir -p $out
    cp enriched.json $out
    cp -r ./templated $out
  '';
}
