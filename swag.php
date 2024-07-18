<?php
$refToken = "#/definitions/";
$refTokenLength = strlen($refToken);

function doc_name($deploy, $doc) {
  $str  = '';
  $str  = strtolower($deploy). "-";
  $str .= strtolower($doc["kind"]). "-";
  $str .= $doc["metadata"]["name"];
  return $str;
}

function doc_enrich($doc) {
  global $definitions;
  global $api;

  $kind = $doc["kind"];
  list ($group, $version) = strpos($doc["apiVersion"], "/") !== false ? explode('/', $doc["apiVersion"]) : ["", $doc["apiVersion"]];
  $api_type_name = @$api["$group/$version/$kind"];
  $api_type = @$definitions[$api_type_name];
  $properties = isset($api_type["properties"]) ? $api_type["properties"] : [];

  $out = [];
  $out = property_enrich($doc, $api_type);

  if (isset($api_type_name)) {
    $out["__api_type"] = $api_type_name;
  }
  $out["__type"] = "object";

  return $out;
}

function property_enrich($content, $meta) {
  global $definitions;
  global $refTokenLength;

  $out = [];
  if (is_string($content) || is_int($content) || is_bool($content) || is_null($content) || is_float($content)) {
    $out["__content"] = $content;
    $out["__type"] = gettype($content);
  } else if (is_array($content) && array_is_list($content)) {
    foreach ($content as $key => $item) {
      $out["__content"][$key] = property_enrich($item, @$meta["items"]);
    }
    $out["__type"] = "array";
  } else if (isset($meta['$ref'])) {
    $ref = $meta['$ref'];
    $api_type_name = substr($ref, $refTokenLength);
    if (isset($definitions[$api_type_name])) {
      $out = property_enrich($content, $definitions[$api_type_name]);
      $out["__api_type"] = $api_type_name;
      $out["__type"] = "object";
    }
  } else if (is_array($content) || is_object($content)) {
    foreach ($content as $key => $item) {
      if (is_null($item) || is_array($item) && count($item) == 0) {
        continue; // skip null and empty attributes
      }
      $properties = is_array(@$meta["properties"]) ? @$meta["properties"][$key] : null;
      $out["__content"][$key] = property_enrich($item, $properties);
    }
    $out["__type"] = "object";
  } else {
    die("Unknown type");
  }

  return $out;
}

$deployName = $argv[1];
$inputDirectory = $argv[2];
$swaggerPath = $argv[3];

// find yaml files recursively in inputDirectory
$files = [];
$iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($inputDirectory));
foreach ($iterator as $file) {
  if ($file->isDir()) {
    continue;
  }
  if (pathinfo($file, PATHINFO_EXTENSION) == "yaml" || pathinfo($file, PATHINFO_EXTENSION) == "yml") {
    $files[] = $file;
  }
}

$swagger = file_get_contents($swaggerPath);

$definitions = json_decode($swagger, true)["definitions"];
$api = [];
foreach ($definitions as $name => $definition) {
  if (isset($definition["x-kubernetes-group-version-kind"])) {
    $group = $definition["x-kubernetes-group-version-kind"][0]["group"];
    $version = $definition["x-kubernetes-group-version-kind"][0]["version"];
    $kind = $definition["x-kubernetes-group-version-kind"][0]["kind"];
    $api["$group/$version/$kind"] = $name;
  }
}

$docs = [];
foreach ($files as $f) {
  $docs = array_merge($docs, yaml_parse_file($f->getPathname(), -1));
}

$output = [];
foreach ($docs as $doc) {
  $output[doc_name($deployName, $doc)] = doc_enrich($doc);
}

echo json_encode($output);
