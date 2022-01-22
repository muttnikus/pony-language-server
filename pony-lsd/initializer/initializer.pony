use "promises"
use jrpc = "jsonrpc"
use "logger"
use "../completion"


actor Initializer
  let _logger: Logger[String]

  new create(logger: Logger[String]) =>
    _logger = logger

  be initialize(request: jrpc.Request val, p: Promise[jrpc.Response val]) =>
    try
      let init_params = InitializeParams.from_request(request)?

      let result: InitializeResult val = recover
        let server_caps = ServerCapabilities
        server_caps.textDocumentSync = TextDocumentSyncKindFull

        let completion_options = CompletionOptions
        completion_options.resolveProvider = true

        server_caps.completionProvider = consume completion_options
        InitializeResult(consume server_caps)
      end

      p(jrpc.Response.success(request.id, result.to_json_type()))
    else
      p(jrpc.Response.from_error(request.id, jrpc.Error.invalid_params()))
    end
