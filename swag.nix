{ config, lib, ... }:
let
  cfg = config.swag;

  renderDocs = i:
    lib.mapAttrs (_: v: render v) i;

  render = ii:
  let
    i = assert builtins.isAttrs ii; ii;
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
  };

  config.swag.input = builtins.fromJSON (builtins.readFile "${cfg.package}/enriched.json");

  config.swag.output = renderDocs cfg.input;
}
