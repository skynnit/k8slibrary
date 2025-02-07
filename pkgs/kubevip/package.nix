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
      hash = "sha256-+b52Jue5pjDJ+ESc4nP4347abj0cbLthTCy/Un+wKug=";
    });

  vendorHash = "sha256-ouMXXMnj/KNPO83axhuFyK5yCL7axyQl2bQB9Gxt3Rg=";

  ldflags = [
    "-X=main.Version=v${version}"
    "-X=main.Build=NixOS"
  ];
}
