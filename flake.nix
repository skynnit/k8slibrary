{
  description = "k8s-library";

  inputs = {
    k8sapi = {
      # 00236ae0d73d2455a2470469ed1005674f8ed61f is a random commit from the top of the kubernetes master branch
      # just to have things pinned down and not change all the time
      url = "https://raw.githubusercontent.com/kubernetes/kubernetes/810e9e212ec5372d16b655f57b9231d8654a2179/api/openapi-spec/swagger.json";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
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

    cephCSI = {
      repoName = "ceph-csi";
      repoUrl = "https://ceph.github.io/csi-charts";
      chartVersion = "3.12.3";
    };
    kubevipVersion = "0.8.7";
  in
  {
    inherit (pkgs) manifests lib kubevip-binary;

    nixosModules.swag = import ./swag.nix;

    overlays.default = final: prev: {
      fetchHelm = final.callPackage ./fetchers/helm {};
      inherit k8sapi;
      kubevip-binary = final.callPackage ./pkgs/kubevip/package.nix { version = kubevipVersion; };
      manifests = {
        argocd = final.callPackage ./pkgs/argocd {};
        ceph-csi-cephfs = final.callPackage ./builders/helm rec{
          deployName = helm.chartName;
          deployNamespace = helm.chartName;
          helm = {
            chartName = "ceph-csi-cephfs";
            chartHash = "sha256-Y1/+xn0Klai//EMIJrS52KvZnoLP/nbHYTgSVTrJ2Nc=";
            inherit (cephCSI) repoName repoUrl chartVersion;
          };
          kubernetes-version = "1.28.0";
        };
        ceph-csi-rbd = final.callPackage ./builders/helm rec{
          deployName = helm.chartName;
          deployNamespace = helm.chartName;
          helm = {
            chartName = "ceph-csi-rbd";
            chartHash = "sha256-SG6pwwhZOYlpLJ0f/t0IJ8HY92cnZ4OOqfdNtnYhjqY=";
            inherit (cephCSI) repoName repoUrl chartVersion;
          };
          kubernetes-version = "1.28.0";
        };
        kube-prometheus-stack = final.callPackage ./builders/helm rec{
          deployName = helm.chartName;
          deployNamespace = helm.chartName;
          helm = {
            repoName = "prometheus-community";
            repoUrl = "https://prometheus-community.github.io/helm-charts";
            chartName = "kube-prometheus-stack";
            chartVersion = "65.5.1";
            chartHash = "sha256-hdlV2AxrpCOPaMaYd2N+9ECRPtdyUwyc7uTpxl2PEf0=";
          };
          kubernetes-version = "1.29.0";
        };
        kubevip = final.callPackage ./pkgs/kubevip { version = kubevipVersion; };
        rancher = final.callPackage ./builders/helm rec{
          deployName = helm.chartName;
          deployNamespace = "cattle-system";
          helm = {
            repoName = "rancher-stable";
            repoUrl = "https://releases.rancher.com/server-charts/stable";
            chartName = "rancher";
            chartVersion = "2.10.0";
            chartHash = "sha256-FJQo/8MiA34kSYJUH6gUTShYAbE24ZN7HA5VOPccgMo=";
          };
          kubernetes-version = "1.29.0";
        };
      };
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        (php.withExtensions ({ enabled, all }:
          enabled ++ [ all.yaml ]))
      ];
    };
  };
}
