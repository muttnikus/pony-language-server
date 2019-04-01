use jsonrpc = "jsonrpc"
use "maybe"
use "rope"
use "logger"

primitive LSPV3
  fun default_content_type(): String => "application/vscode-jsonrpc; charset=utf-8"

  fun content_length(): String => "Content-Length: "


primitive _ExpectHeaders
primitive _ExpectBody

type _ParserState is ( _ExpectHeaders | _ExpectBody )


primitive LSPV3RequestParseError

type ParseError is ( jsonrpc.ParseError | LSPV3RequestParseError )
type ParseResult is ( jsonrpc.Request | jsonrpc.BatchRequest | ParseError )

class RequestParser is Iterator[ParseResult]
  let _cl: String = LSPV3.content_length()
  let _logger: Logger[String]

  embed _requests: Array[ParseResult] = []

  var _data: Rope = Rope.create()
  var _state: _ParserState = _ExpectHeaders
  var _expected_body_size: USize = 0

  new create(logger: Logger[String]) =>
    _logger = logger

  fun ref add(data: Array[U8] iso): None => None
    _data = _data.add(
      recover val
        consume data
      end)
    //_logger(Fine) and _logger.log("DATA: |" + _data.string() + "|")
    _parse_requests()

  fun ref _parse_requests() =>
    var carry_on: Bool = true
    _logger(Fine) and _logger.log("Parser expecting " + match _state
      | _ExpectHeaders => "Headers"
      | _ExpectBody   => "Body"
      end)
    _logger(Fine) and _logger.log("Available data: " + _data.size().string())
    while carry_on do
      match _state
      | _ExpectHeaders =>
        carry_on = _parse_headers()
      | _ExpectBody =>
        carry_on = _parse_body()
      end
    end

  fun ref _parse_error(pe: ParseError): Bool =>
    _requests.push(pe)

    _expected_body_size = 0
    _state = _ExpectHeaders
    _data.size() > 0

  fun ref _parse_headers(): Bool =>
    match _data.find("\r\n\r\n")
    | (true, let index: USize) =>
      _logger(Fine) and _logger.log("Headers complete.")
      let headers = _data.take(index + 2)
      _data = _data.drop(index + 4) // cut off headers
      // look for Content-Length header
      //_logger(Fine) and _logger.log("HEADERS: |" + headers.string() + "|")
      match headers.find(_cl)
      | (true, let cl_index: USize) =>
        let cl_value =
          match headers.drop(cl_index).find("\r\n")
          | (true, let cl_end_index: USize) =>
            headers.slice(cl_index + _cl.size(), cl_index + cl_end_index)
          else
            _logger(Fine) and _logger.log("Weird! No \\r\\n after Content-Length")
            return _parse_error(LSPV3RequestParseError)
          end
        // extract header value as U64
        try
          //_logger(Fine) and _logger.log("Content-Length: |" + cl_value.string() + "|")
          _expected_body_size = cl_value.string().usize()?
          _logger(Fine) and _logger.log("Content-Length: " + _expected_body_size.string())
        else
          _logger(Fine) and _logger.log("Content-Length not parseable as int")
          return _parse_error(LSPV3RequestParseError)
        end
        _state = _ExpectBody
        _parse_body()
      else
        // no Content-Length in headers
        _logger(Fine) and _logger.log("No Content-Length in headers")
        _parse_error(LSPV3RequestParseError)
      end
    else
      // headers not complete yet
      _logger(Fine) and _logger.log("Headers not complete yet.")
      false
    end

  fun ref _parse_body(): Bool =>
    // TODO: determine minimum size of a JSONRPC message
    //_logger(Fine) and _logger.log("BODY TO PARSE: [" + _data.string() + "]")
    if _expected_body_size < 10 then
      // invalid or missing Content-Length
      _logger(Fine) and _logger.log("invalid Content-Length of " + _expected_body_size.string())
      _parse_error(LSPV3RequestParseError)
    elseif _data.size() >= _expected_body_size then
      // might be request or parse error
      _requests.push(jsonrpc.RequestParser.parse_request(_data.take(_expected_body_size).string()))

      // cleanup
      _data = _data.drop(_expected_body_size)
      _expected_body_size = 0
      _state = _ExpectHeaders
      //_logger(Fine) and _logger.log("body parsed. " + _data.size().string() + " bytes left to parse.")
      _data.size() > 0 // carry on if stuff is available
    else
      false
    end

  fun ref has_next(): Bool => _requests.size() > 0

  fun ref next(): ParseResult ? => _requests.shift()?

