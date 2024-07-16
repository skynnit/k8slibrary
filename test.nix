let
  flake = builtins.getFlake (toString ./.);
in
  (flake.lib.evalModules {
    modules = [
      flake.outputs.nixosModules.swag
      ({...}: {
        config.swag.package = flake.charts.rancher;
      })
    ];
  }).config.swag