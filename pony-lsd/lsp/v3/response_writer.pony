use jsonrpc = "jsonrpc"
use "debug"
use "logger"

interface val Jsonable
  fun box to_json(): String

interface tag AsyncWritable
  be write(data: ByteSeq)

class val ResponseWriter
  let _stream: AsyncWritable
  let _logger: Logger[String]

  new val create(stream: AsyncWritable, logger: Logger[String]) =>
    _stream = stream
    _logger = logger

  fun write(response: Jsonable) =>
    let payload = response.to_json()
    _logger(Fine) and _logger.log("===>\n\t" + payload)
    let p_size = payload.size().string()
    let cl = LSPV3.content_length()
    let size = cl.size() + p_size.size() + 4 + payload.size()
    let s = recover trn String(size)
      .>append(cl)
      .>append(consume p_size)
      .>append("\r\n\r\n")
      .>append(payload)
    end
    _stream.write(consume s)
