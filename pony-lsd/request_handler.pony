use jsonrpc = "jsonrpc"
use "logger"
use "lsp/v3"
use "promises"

class RequestHandler
  let _logger: Logger[String]
  let _out: AsyncWritable
  let _parser: RequestParser
  let _dispatcher: jsonrpc.Dispatcher
  let _response_writer: ResponseWriter

  new iso create(
    dispatcher: jsonrpc.Dispatcher,
    logger: Logger[String],
    out: AsyncWritable) =>
    _logger = logger
    _out = out
    _parser = RequestParser.create(_logger)
    _dispatcher = dispatcher
    _response_writer = ResponseWriter(_out, _logger)

  fun ref _handle_request(pr: ParseResult, allow_batch: Bool = true): ( Promise[(jsonrpc.Response | jsonrpc.BatchResponse)] | None ) =>
    match pr
    | let req: jsonrpc.Request val =>
      _logger(Fine) and _logger.log("<===\n\t" + req.to_json())
      let res_promise: Promise[jsonrpc.Response] = _dispatcher(req)
      if not req.is_notification() then
        res_promise.next[(jsonrpc.Response | jsonrpc.BatchResponse)]({(r) => r})
      end
    | let batch_req: jsonrpc.BatchRequest =>
      _logger(Fine) and _logger.log(batch_req.to_json())
      let responses = Array[Promise[jsonrpc.Response]](batch_req.size())
      for req in batch_req.requests.values() do
         // recurse
         match _handle_request(req where allow_batch = false)
         | let res_promise: Promise[(jsonrpc.Response | jsonrpc.BatchResponse)] =>
           responses.push(res_promise.next[jsonrpc.Response](
             {(r) ? => r as jsonrpc.Response}))
         end
      end
      if responses.size() == 0 then
        None // only notifications, or weird errors
      else
        Promises[jsonrpc.Response].join(responses.values())
          .next[(jsonrpc.Response | jsonrpc.BatchResponse)](
            {(responses) => jsonrpc.BatchResponse(responses) })
      end
    | let invalidJson: jsonrpc.InvalidJson =>
      _logger(Warn) and _logger.log("invalid JSON")
      response_promise(jsonrpc.Response.from_error(None, jsonrpc.Error.parse_error()))
    | let invalidJsonRPCRequest: jsonrpc.InvalidRequest =>
      _logger(Warn) and _logger.log("invalid JSONRPC message.")
      response_promise(jsonrpc.Response.from_error(None, jsonrpc.Error.invalid_request()))
    | let lspErr: LSPV3RequestParseError =>
      _logger(Warn) and _logger.log("invalid LSPV3 message.")
      response_promise(jsonrpc.Response.from_error(None, jsonrpc.Error.invalid_request()))
    end

  fun tag response_promise(res: jsonrpc.Response): Promise[(jsonrpc.Response | jsonrpc.BatchResponse)] =>
    Promise[(jsonrpc.Response | jsonrpc.BatchResponse)].>apply(res)

  fun ref apply(data: Array[U8] iso) =>
    """
    pass incoming data to the LSPv3 request parser
    and handle any request that comes out.
    """
    _logger(Fine) and _logger.log("received " + data.size().string() + " bytes.")
    _parser + consume data
    for request in _parser do
      match _handle_request(request)
      | let res: Promise[(jsonrpc.Response | jsonrpc.BatchResponse)] =>
        // write response
        res.next[None](
          {(response) => _response_writer.write(response) },
          // promise is rejected if no handler is found
          { () =>
            _response_writer.write(
              jsonrpc.Response.from_error(
                None, jsonrpc.Error.method_not_found()))
          })
      | None =>
        _logger(Fine) and _logger.log("Notification. Won't send a response.")
      end
    end

  fun ref dispose() =>
    _logger(Info) and _logger.log("EOF on STDIN.")
