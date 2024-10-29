{
  description = "k8s-library";

  inputs = {
    k8sapi = {
      # 00236ae0d73d2455a2470469ed1005674f8ed61f is a random commit from the top of the kubernetes master branch
      # just to have things pinned down and not change all the time
      url = "https://raw.githubusercontent.com/kubernetes/kubernetes/00236ae0d73d2455a2470469ed1005674f8ed61f/api/openapi-spec/swagger.json";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, k8sapi, nixpkgs, ... }@attrs:
  let
    pname = "k8s-library";
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        self.overlays.default
      ];
    };
  in
  {
    inherit (pkgs) manifests lib;

    nixosModules.swag = import ./swag.nix;

    overlays.default = final: prev: {
      fetchHelm = final.callPackage ./fetchers/helm {};
      inherit k8sapi;
      manifests = {
        argocd = final.callPackage ./pkgs/argocd {};
        ceph-csi-cephfs = final.callPackage ./builders/helm rec{
          deployName = helm.chartName;
          deployNamespace = helm.chartName;
          helm = {
            repoName = "ceph-csi";
            repoUrl = "https://ceph.github.io/csi-charts";
            chartName = "ceph-csi-cephfs";
            chartVersion = "3.12.2";
            chartHash = "sha256-O/qmg8N2ZkZ5QjOeEj7M0IyddowdD13bWGuMx9St1IU=";
          };
          kubernetes-version = "1.28.0";
        };
        rancher = final.callPackage ./builders/helm rec{
          deployName = helm.chartName;
          deployNamespace = "cattle-system";
          helm = {
            repoName = "rancher-stable";
            repoUrl = "https://releases.rancher.com/server-charts/stable";
            chartName = "rancher";
            chartVersion = "2.9.2";
            chartHash = "sha256-YPTdkRoh3W9vuWkVBBrIqGQJR6Zop8LxaLBHQtjpR+4=";
          };
          kubernetes-version = "1.29.0";
        };
      };
    };

    devShell.${system} = pkgs.mkShell {
      buildInputs = with pkgs; [
        (php.withExtensions ({ enabled, all }:
          enabled ++ [ all.yaml ]))
      ];
    };
  };
}
