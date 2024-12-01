{
  stdenv,
  kubevip-binary,
  php,
  yq-go,
  k8sapi,
  fetchurl,
  version,
  deployName ? "kubevip",
  deployNamespace ? "kubevip",
  kubernetes-version ? "1.28.0",
  values ? {
    interface = "eth0"; vip = "10.0.0.1"; # defaults
  }
}:
let
  yamlPHP = 
    php.withExtensions ({ enabled, all }:
      enabled ++ [ all.yaml ]);
in
stdenv.mkDerivation rec{
  pname = deployName;
  inherit version;

  src = fetchurl {
    url = "https://kube-vip.io/manifests/rbac.yaml";
    hash = "sha256-B6018KsDpuhPq4PjJxGHszmvzuQuqnPd9e2AoNH21tg=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ yq-go kubevip-binary ];

  buildPhase = ''
    mkdir templated
    kube-vip manifest daemonset \
      --interface ${values.interface} \
      --address ${values.vip} \
      --inCluster \
      --taint \
      --controlplane \
      --services \
      --arp \
      --leaderElection \
      >templated/daemonset.yaml

    cp $src templated/rbac.yaml

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