use "cli"
use "net"
use "logger"
use jrpc = "jsonrpc"
use "initializer"
use "promises"

use @getpid[I32]()


actor Main

  new create(env: Env) =>
    let pid: I32 = @getpid()
    let cs =
      try
        CommandSpec.leaf(
          "pony-lsd",
          "Pony Language Server Daemon",
          [
            OptionSpec.string("tcp", "\"<host>:<port>\" where to listen for client commands via TCP additionally to listening on stdin" where default' = "")
            OptionSpec.bool("debug", "enable debug logs on stdout" where default' = false)
            ], [])? .> add_help()?
      else
        env.exitcode(1)
        env.err.print("Error setting up CLI")
        return
      end

    let cmd =
      match CommandParser(cs).parse(env.args, env.vars)
      | let c: Command => c
      | let ch: CommandHelp =>
        ch.print_help(env.out)
        env.exitcode(0)
        return
      | let se: SyntaxError =>
        env.out.print(se.string())
        env.exitcode(1)
        return
      end
    let debug = cmd.option("debug").bool()
    let logger = StringLogger(if debug then Fine else Info end, env.err)
    logger(Fine) and logger.log("PID: " + pid.string())

    let dispatcher = _create_dispatcher(logger)
    let tcp = cmd.option("tcp").string()
    let tcp_server =
      if tcp.size() > 0 then
        try
          let splitted = tcp.split(":", 2)
          let host = splitted(0)?
          let port =
            if splitted.size() == 2 then
              splitted(1)?.u16()?
            else
              U16(65535)
            end
          TCPLanguageServer(
            env.root as TCPListenerAuth,
            host,
            port,
            dispatcher,
            logger)
        else
          logger(Error) and logger.log("Unable to spawn TCP server for " + tcp)
          env.exitcode(1)
          return
        end
      end
    let stdin_stdout_server =
      StdinStdoutLanguageServer(
        env.input,
        env.out,
        dispatcher,
        logger)

  fun box _create_dispatcher(logger: Logger[String]): jrpc.Dispatcher =>
    let dispatcher = jrpc.Dispatcher.create()

    let initializer = Initializer(logger)

    dispatcher.register_handler("initialize", object is jrpc.MethodHandler
      be handle(request: jrpc.Request val, p: Promise[jrpc.Response val]) =>
        initializer.initialize(request, p)
    end)

    dispatcher
