use "net"
use "logger"
use jsonrpc = "jsonrpc"

actor TCPLanguageServer
  let _listener: TCPListener
  let _logger: Logger[String]

  new create(
    auth: TCPListenerAuth,
    host: String,
    port: U16,
    dispatcher: jsonrpc.Dispatcher,
    logger: Logger[String])
  =>
    let notify = LanguageServerNotify.create(dispatcher, logger)
    _listener =
      TCPListener(
        auth,
        consume notify,
        host,
        port.string())
    _logger = logger

  be dispose() =>
    _logger(Info) and _logger.log("closing TCP...")
    _listener.dispose()


class iso LanguageServerNotify is TCPListenNotify
  let _dispatcher: jsonrpc.Dispatcher
  let _logger: Logger[String]
  var _connection_count: U64 = 0

  new iso create(dispatcher: jsonrpc.Dispatcher, logger: Logger[String]) =>
    _dispatcher = dispatcher
    _logger = logger

  fun ref listening(listen: TCPListener ref) =>
    try
      _logger(Info) and (
        (let addr, let port) = listen.local_address().name()?
        _logger.log("listening on " + addr + ":" + port))
    end

  fun ref not_listening(listen: TCPListener ref) =>
    try
      _logger(Error) and (
        (let addr, let port) = listen.local_address().name()?
        _logger.log("unable to listen on " + addr + ":" + port)
      )
    end

  fun ref closed(listen: TCPListener ref) =>
    _logger(Info) and _logger.log("TCP closed.")

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    ConnectionNotify.create(_dispatcher, _logger, _connection_count = _connection_count + 1)


class ConnectionNotify is TCPConnectionNotify
  let _dispatcher: jsonrpc.Dispatcher
  let _logger: Logger[String]
  let _id: U64
  var _handler: (RequestHandler | None) = None

  new iso create(dispatcher: jsonrpc.Dispatcher, logger: Logger[String], id: U64) =>
    _dispatcher = dispatcher
    _logger = logger
    _id = id

  fun ref accepted(conn: TCPConnection ref) =>
    _logger(Fine) and _logger.log("connection " + _id.string() + " accepted. Initializing request handler.")
    _handler = RequestHandler(_dispatcher, _logger, conn)

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    try
      (_handler as RequestHandler).apply(consume data)
    else
      _logger(Fine) and _logger.log("Connection " + _id.string() + " _handler is None. :(")
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

  fun ref closed(conn: TCPConnection ref) =>
    _logger(Fine) and _logger.log("Connection " + _id.string() + " closed.")
