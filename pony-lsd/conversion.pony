use "immutable-json"


interface FromJsonType
  new from_json_type(json_type: JsonType)


interface ToJsonType
  fun to_json_type(): JsonType
