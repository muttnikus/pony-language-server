use jsonrpc = "jsonrpc"
use "debug"

interface val Jsonable
  fun box to_json(): String

primitive ResponseWriter
  fun tag write(response: Jsonable, stream: OutStream) =>
    let payload = response.to_json()
    Debug(payload where stream = DebugErr)
    let p_size = payload.size().string()
    let cl = LSPV3.content_length()
    let size = cl.size() + p_size.size() + 4 + payload.size()
    let s = recover trn String(size)
      .>append(cl)
      .>append(consume p_size)
      .>append("\r\n\r\n")
      .>append(payload)
    end
    stream.write(consume s)

