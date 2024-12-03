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

  vendorHash = "sha256-muKC4YGH924FWGUIJ0ZPB5qNSPtSvKnYS5VBWfAT81E=";

  ldflags = [
    "-X=main.Version=v${version}"
    "-X=main.Build=NixOS"
  ];
}
