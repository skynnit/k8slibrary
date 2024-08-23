let
  flake = builtins.getFlake (toString ./.);
in
  (flake.lib.evalModules {
    modules = [
      flake.outputs.nixosModules.swag
      ({ config, ... }: {
        config.swag.apps.rancher.package = flake.manifests.rancher.override {
          values.hostname = "rancher.test.local";
        };

        config.swag.apps.rancher.patches = config.swag.lib.setNamespace "cattle-system";
      })
    ];
  }).config.swag.apps.rancher