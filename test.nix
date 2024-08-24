let
  flake = builtins.getFlake (toString ./.);
in
  (flake.lib.evalModules {
    modules = [
      flake.outputs.nixosModules.swag
      ({ config, ... }: {
        config.swag.apps.argocd.package = flake.manifests.argocd;

        config.swag.apps.argocd.patches = config.swag.lib.setNamespace "argocd";
      })
    ];
  }).config.swag.apps.argocd