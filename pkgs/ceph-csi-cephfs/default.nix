{
  stdenv,
  fetchHelm,
  kubernetes-helm,
  writeText,
  yq-go,
  php,
  k8sapi,
  deployName ? "ceph-csi-cephfs",
  deployNamespace ? "ceph-csi-cephfs",
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
  pname = "ceph-csi-cephfs";
  version = "3.12.2";

  src = fetchHelm {
    repo = {
      name = "ceph-csi";
      url = "https://ceph.github.io/csi-charts";
    };
    chart = "ceph-csi-cephfs";
    inherit version;
    hash = "sha256-O/qmg8N2ZkZ5QjOeEj7M0IyddowdD13bWGuMx9St1IU=";
  };

  nativeBuildInputs = [ kubernetes-helm yq-go ];

  unpackPhase = ''
    mkdir ./templated
    helm template \
      --include-crds \
      --namespace ${deployNamespace} \
      -f ${writeText "${pname}-values.json" (builtins.toJSON values)} \
      --kube-version ${kubernetes-version} \
      --output-dir ./templated \
      ceph-csi-cephfs \
      $src
  '';

  buildPhase = ''
    yq -o json -s '.kind + "_" + .metadata.name + ".json"' templated/ceph-csi-cephfs/templates/*.yaml
    cp *.json templated
    ${yamlPHP}/bin/php ${../../swag.php} ${deployName} ./templated ${k8sapi} > enriched.json
  '';

  installPhase = ''
    mkdir -p $out
    cp enriched.json $out
    cp -r ./templated $out
  '';
}
