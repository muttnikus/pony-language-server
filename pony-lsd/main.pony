use "cli"
use "net"
use "logger"
use jsonrpc = "jsonrpc"

actor Main

  new create(env: Env) =>
    let pid: I32 = @getpid[I32]()
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

    let dispatcher = jsonrpc.Dispatcher.create()
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
            env, // TODO: narrow down what needs to be passed
            env.root as TCPListenerAuth,
            host,
            port,
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


