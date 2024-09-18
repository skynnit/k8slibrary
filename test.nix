let
  flake = builtins.getFlake (toString ./.);
  output = p: _: (flake.lib.evalModules {
    modules = [
      flake.outputs.nixosModules.swag
      ({ config, ... }: {
        config.swag.apps.${p} = {
          package = flake.manifests.${p};
          patches =
            config.swag.lib.setNamespace "${p}"
            ++
            config.swag.lib.scale 1
            ++
            config.swag.lib.addConfigMapData "argocd-cm" ({ "server.insecure" = "true"; })
            ++
            config.swag.lib.removePodAntiAffinityRule "requiredDuringSchedulingIgnoredDuringExecution";
        };
      })
    ];
  }).config.swag.apps.${p}.output;
in
  builtins.mapAttrs output flake.outputs.manifests
