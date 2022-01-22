use "maybe"
use "collections"
use "immutable-json"
use ".."


type TextDocumentSyncKind is (TextDocumentSyncKindNone | TextDocumentSyncKindFull | TextDocumentSyncKindIncremental)
  """
  Defines how the host (editor) should sync document changes to the language server.
  """

primitive TextDocumentSyncKindNone
  """
  Documents should not be synced at all.
  """

  fun apply(): I64 => I64(0)

  fun to_json_type(): JsonType => apply()


primitive TextDocumentSyncKindFull
  """
  Documents are synced by always sending the full content of the document.
  """

  fun apply(): I64 => I64(1)

  fun to_json_type(): JsonType => apply()


primitive TextDocumentSyncKindIncremental
  """
  Documents are synced by sending the full content on open. After that only incremental updates to
  the document are send.
  """

  fun apply(): I64 => I64(2)

  fun to_json_type(): JsonType => apply()


class val TextDocumentSyncOptions
  var openClose: Maybe[Bool] = None
  """
  Open and close notifications are sent to the server. If omitted open close notification should not be sent.
  """

  var change: Maybe[TextDocumentSyncKind] = None
  """
  Change notifications are sent to the server. See TextDocumentSyncKindNone, TextDocumentSyncKindFull and
  TextDocumentSyncKindIncremental. If omitted it defaults to TextDocumentSyncKindNone.
  """

  fun to_json_type(): JsonType =>
    let dmap: Map[String, JsonType] val = recover
      let map = Map[String, JsonType]

      Opt[Bool](openClose, {ref(value) => map("openClose") = value})
      Opt[TextDocumentSyncKind](change, {ref(value) => map("change") = value.to_json_type() })

      map
    end
    JsonObject(dmap)


class val CompletionOptions

  var triggerCharacters: Maybe[Array[String]] = None
  """
  Most tools trigger completion request automatically without explicitly requesting it using a keyboard shortcut
  (e.g. Ctrl+Space). Typically they do so when the user starts to type an identifier. For example if the user
  types `c` in a JavaScript file code complete will automatically pop up present `console` besides others as
  a completion item. Characters that make up identifiers don't need to be listed here.

  If code complete should automatically be trigger on characters not being valid inside an identifier
  (for example `.` in JavaScript) list them in `triggerCharacters`.
  """

  var allCommitCharacters: Maybe[Array[String]] = None
  """
  The list of all possible characters that commit a completion. This field can be used if clients don't support
  individual commit characters per completion item. See client capability
  `completion.completionItem.commitCharactersSupport`.

  If a server provides both `allCommitCharacters` and commit characters on an individual completion item the ones
  on the completion item win.
  """

  var resolveProvider: Maybe[Bool] = None
  """
  The server provides support to resolve additional information for a completion item.
  """

  // TODO completionItem

  fun box to_json_type(): JsonType =>
    let dmap: Map[String, JsonType] val = recover
      let map = Map[String, JsonType]

      Opt[Bool](resolveProvider, {ref(value) => map("resolveProvider") = value})

      map
    end
    JsonObject(dmap)
