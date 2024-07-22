{ config, lib, ... }:
let
  cfg = config.swag;

  renderDocs = i:
    lib.mapAttrs (n: v: render (patch v)) i;

  patch = d: lib.foldl' (a: f: f a) d cfg.patches;

  render = ii:
  let
    i = if !builtins.isAttrs ii then throw "init object assertion: ${builtins.toJSON ii}" else ii;
    content = if (i.__content or null) == null then "undefined content: ${builtins.toJSON i}" else i.__content;
    typ = if (i.__type or null) == null then throw "undefined type: ${builtins.toJSON i}" else i.__type;
  in
    if typ == "object" then
      if builtins.isAttrs content then
        lib.mapAttrs (_: v: render v) (lib.filterAttrs (n: _: n != "__type") content)
      else throw "object assertion: ${builtins.toJSON content}"
    else if typ == "array" then
      if builtins.isList content then
        lib.map render content
      else throw "array assertion: ${builtins.toJSON content}"
    else content;

  mutate' =
    with builtins; apiType: f: s: (
    if isAttrs s && s ? __api_type && s.__api_type == apiType then s // { __content = f s.__content; }
    else if isAttrs s && s ? __content then s // { __content = mutate' apiType f s.__content; }
    else if isAttrs s then lib.mapAttrs (_: v: mutate' apiType f v) s
    else if isList s then map (v: mutate' apiType f v) s
    else s);

in
{
  options.swag = with lib; with lib.types; {
    package = mkOption {
      type = package;
    };

    patchFunctions = mkOption {
      type = types.list;
      default = [];
    };

    input = mkOption {
      type = attrsOf attrs;
    };

    output = mkOption {
      type = attrsOf attrs;
    };

    lib = mkOption {
      type = attrs;
    };

    patches = mkOption {
      type = listOf anything;
      default = [];
    };
  };

  config.swag.input = builtins.fromJSON (builtins.readFile "${cfg.package}/enriched.json");

  config.swag.output = renderDocs cfg.input;

  config.swag.lib = rec{
    mapAPIType = type: f: lib.mapAttrs (_: d: mutate' type f d);
    setSimple = type: new: mapAPIType type (old: old // (lib.mapAttrs (n: v: {
      __type = "string";
      __content = v;
    }) new));
    setNamespace = namespace: let phrase = { inherit namespace; }; in [
      (setSimple "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta" phrase)
      (setSimple "io.k8s.api.rbac.v1.Subject" phrase)
    ];
  };
}
