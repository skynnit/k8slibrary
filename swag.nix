{ config, lib, ... }:
let
  cfg = config.swag;

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


  getMetadataName = queryAttrByPath ["metadata" "name"];

  queryAttrByPath = path: obj:
    let
      subject = render obj;
    in
      lib.attrByPath path null subject;

  mutate' =
    with builtins; apiType: f: s: (
    if isAttrs s && s ? __api_type && s.__api_type == apiType then f s
    else if isAttrs s && s ? __content then s // { __content = mutate' apiType f s.__content; }
    else if isAttrs s then lib.mapAttrs (_: v: mutate' apiType f v) s
    else if isList s then map (v: mutate' apiType f v) s
    else s);

  module = with lib; with lib.types; submodule ({config, lib, ...}: {
    options = {
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

    config.input = builtins.fromJSON (builtins.readFile "${config.package}/enriched.json");
    config.output = config.lib.renderDocs config.input;

    config.lib = rec{
      renderDocs = i:
        lib.mapAttrs (n: v: render (patch v)) i;

      patch = d: lib.foldl' (a: f: f a) d config.patches;
    };
  });

in
{
  options.swag.apps = lib.mkOption {
    type = lib.types.attrsOf module;
    default = {};
  };

  options.swag.lib = lib.mkOption {
    type = lib.types.attrs;
  };

  config.swag.lib = rec{
    mapAPIType = type: f: mutate' type f;
    injectContent = new: old: old // { "__content" = old.__content // (lib.mapAttrs (n: v: {
      __type = "string";
      __content = v;
    }) new); };
    removePropertyPlumbing = name: obj:
      obj // { __content = builtins.removeAttrs obj.__content [name]; };
    removeProperty = type: property: mapAPIType type (removePropertyPlumbing property);
    setSimple = type: new: mapAPIType type (injectContent new);
    setSimpleNamed = type: name: new: mapAPIType type (old: let oName = getMetadataName old; in if oName == name then injectContent new old else old);
    setNamespace = namespace: let phrase = { inherit namespace; }; in [
      (setSimple "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta" phrase)
      (setSimple "io.k8s.api.rbac.v1.Subject" phrase)
    ];
    scale = replicas: let phrase = { replicas = assert builtins.isInt replicas; replicas; }; in [
      (setSimple "io.k8s.api.apps.v1.DeploymentSpec" phrase)
      (setSimple "io.k8s.api.apps.v1.StatefulSetSpec" phrase)
    ];
    addConfigMapData = name: data: let phrase = { inherit data; }; in [
      (setSimpleNamed "io.k8s.api.core.v1.ConfigMap" name phrase)
    ];
    removePodAntiAffinityRule = rule: [
      (removeProperty "io.k8s.api.core.v1.PodAntiAffinity" rule)
    ];
  };
}
