let
  flake = builtins.getFlake (toString ./.);
in
  (flake.lib.evalModules {
    modules = [
      flake.outputs.nixosModules.swag
      ({ config, ... }: {
        config.swag.package = flake.charts.rancher;

        config.swag.patches = [
          (config.swag.lib.mapAPIType "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta" (metadata: metadata // {
            namespace = {
              __content = "cattle-system";
              __type = "string";
            };
          }))
        ];
      })
    ];
  }).config.swag