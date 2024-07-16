{
  description = "k8s-library";

  inputs = {
    k8sapi = {
      url = "https://raw.githubusercontent.com/kubernetes/kubernetes/release-1.29/api/openapi-spec/swagger.json";
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
        (self: super: {
          fetchHelm = self.callPackage ./fetchers/helm {};
          inherit k8sapi;
          charts = {
            rancher = self.callPackage ./pkgs/rancher {};
          };
        })
      ];
    };

    lib = pkgs.lib; 
  in
  {
    nixosModules.swag = import ./swag.nix;
    charts = pkgs.charts;
    inherit lib;

    devShell.${system} = pkgs.mkShell {
      buildInputs = with pkgs; [
        (php.withExtensions ({ enabled, all }:
          enabled ++ [ all.yaml ]))
      ];
    };
  };
}
