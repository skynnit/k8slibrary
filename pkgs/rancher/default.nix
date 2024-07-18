{
  stdenv,
  fetchHelm,
  kubernetes-helm,
  writeText,
  php,
  k8sapi,
  deployName ? "rancher",
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
  version = "2.8.5";

  src = fetchHelm {
    repo = {
      name = "rancher-stable";
      url = "https://releases.rancher.com/server-charts/stable";
    };
    chart = "rancher";
    inherit version;
    hash = "sha256-khL7tZ9hSzY/YsU2O2KnVR8Miehl5VT6wwmcpApLTdA=";
  };

  nativeBuildInputs = [ kubernetes-helm ];

  unpackPhase = ''
    mkdir ./templated
    helm template \
      -f ${writeText "${pname}-values.json" (builtins.toJSON values)} \
      --kube-version ${kubernetes-version} \
      --output-dir ./templated \
      rancher \
      $src
  '';

  buildPhase = ''
    ${yamlPHP}/bin/php ${../../swag.php} ${deployName} ./templated ${k8sapi} > enriched.json
  '';

  installPhase = ''
    mkdir -p $out
    cp enriched.json $out
    cp -r ./templated $out
  '';
}
