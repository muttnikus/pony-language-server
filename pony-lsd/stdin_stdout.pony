use "logger"
use "lsp/v3"
use jsonrpc = "jsonrpc"
use "promises"

actor StdinStdoutLanguageServer
  new create(in_stream: InputStream,
             out_stream: OutStream,
             dispatcher: jsonrpc.Dispatcher,
             logger: Logger[String],
             chunk_size: USize = 512) =>
    let out_stream' = AutoFlushableStream(out_stream)
    let request_handler = recover iso RequestHandler(dispatcher, logger, out_stream') end
    in_stream.apply(StdinNotify(logger, consume request_handler), chunk_size)

class iso StdinNotify is InputNotify
  let _logger: Logger[String]
  let _handler: RequestHandler iso

  new iso create(
    logger: Logger[String],
    request_handler: RequestHandler iso) =>
    _logger = logger
    _handler = consume request_handler

  fun ref apply(data: Array[U8] iso) =>
    """
    """
    _handler.apply(consume data)

  fun ref dispose() =>
    _logger(Info) and _logger.log("EOF on STDIN.")
    _handler.dispose()

actor AutoFlushableStream
  let _out_stream: OutStream

  new create(out_stream: OutStream) =>
    _out_stream = out_stream

  be write(data: ByteSeq) =>
    _out_stream.write(data)
    _out_stream.flush()
