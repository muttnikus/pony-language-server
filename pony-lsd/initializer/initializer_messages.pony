use "immutable-json"
use jrpc = "jsonrpc"
use "maybe"
use "collections"
use ".."
use "../completion"

class val InitializeParams
  let body: JsonObject

  new val from_request(req: jrpc.Request) ? =>
    body = req.params as JsonObject

class val InitializeResult
  """
  The message the server by which the server responds to the initialization request.
  """

  var capabilities: ServerCapabilities
  """
  The capabilities the language server provides.
  """

  new create(capabilities': ServerCapabilities) =>
    capabilities = capabilities'

  fun box to_json_type(): JsonType =>
    let dmap: Map[String, JsonType] val = recover
      let map = Map[String, JsonType]

      Opt[ServerCapabilities](capabilities, {ref(value) => map("capabilities") = value.to_json_type() })

      map
    end

    JsonObject(dmap)


class val ServerCapabilities
  """
  The capabilities the language server provides.
  """

  var textDocumentSync: Maybe[(TextDocumentSyncOptions | TextDocumentSyncKind)] = None
  """
  Defines how text documents are synced. Is either a detailed structure defining each notification or for backwards
  compatibility the TextDocumentSyncKind number. If omitted it defaults to TextDocumentSyncKindNone.
  """

  var completionProvider: Maybe[CompletionOptions] = None
  """
  The server provides completion support.
  """

  fun box to_json_type(): JsonType =>
    let dmap: Map[String, JsonType] val = recover
      let map = Map[String, JsonType]

      Opt[(TextDocumentSyncOptions | TextDocumentSyncKind)](textDocumentSync, {ref(value) =>
        map("textDocumentSync") = value.to_json_type()
        })
      Opt[CompletionOptions](completionProvider, {ref(value) => map("completionProvider") = value.to_json_type()})

      map
    end
    JsonObject(dmap)
