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

  srcs = [
    (fetchurl {
      name = "rbac.yaml";
      url = "https://kube-vip.io/manifests/rbac.yaml";
      hash = "sha256-aK1Jr2air67M4vXHWUzq39Un7Rrz3DkVjIKcZ6xvxkI=";
    })
    (fetchurl {
      name = "cloud-controller.yaml";
      url = "https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml";
      hash = "sha256-PaAdaL1EdLQEeoQuHkD/dPv+bT0zmr+sNG7cxksvCrk=";
    })
  ];

  unpackPhase = ''
    for s in $srcs; do
      d=$(stripHash $s)
      cp -v $s ./$d
    done
  '';

  prePatch = ''
    mkdir templated
    kube-vip manifest daemonset \
      --interface ${values.interface} \
      --address ${values.vip} \
      --inCluster \
      --taint \
      --controlplane \
      --services \
      --servicesElection \
      --arp \
      --leaderElection \
      --enableLoadBalancer \
      --lbForwardingMethod masquerade \
      >daemonset.yaml
  '';

  patches = [
    # wait for upstream fix of: https://github.com/kube-vip/kube-vip/issues/874
    ./iptables-image.patch
    # Since we are using the RKE2 Addon manager on Hetzvester at the moment,
    # and it doesn't like colon (:) in k8s object names, we need to patch the
    # upstream kubevip rbac manifest and give roles and rolebindings new (rke2-safe) names.
    ./cloud-controller-rbac.patch
    ./rbac.patch
  ];

  nativeBuildInputs = [ yq-go kubevip-binary ];

  buildPhase = ''
    runHook preBuild
    cp *.yaml templated
    yq -o json -s '.kind + "_" + .metadata.name + ".json"' templated/*.yaml
    cp *.json templated
    ${yamlPHP}/bin/php ${../../swag.php} ${deployName} templated/ ${k8sapi} > enriched.json
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r templated $out
    cp enriched.json $out
    runHook postInstall
  '';
}
