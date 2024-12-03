{
  buildGoModule,
  fetchFromGitHub,
  version
}:
buildGoModule rec {
  pname = "kube-vip";
  inherit version;

  src = builtins.filterSource
    (path: type: type != "directory" || (baseNameOf path != "demo" && baseNameOf path != "testing"))
    (fetchFromGitHub {
      owner = "kube-vip";
      repo = "kube-vip";
      rev = "v${version}";
      hash = "sha256-65BLB3eCB1ISDoC/+hvFlf2HF5c0k4PevL6pNshyRlQ=";
    });

  vendorHash = "sha256-84nX5wd9K44WMKeRpNlSI1lcvhk4iGEPD6hV0FwMrK4=";

  ldflags = [
    "-X=main.Version=v${version}"
    "-X=main.Build=NixOS"
  ];
}
