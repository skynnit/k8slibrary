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
        rancher = final.callPackage ./pkgs/rancher {};
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
