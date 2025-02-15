-- json.lua (from https://github.com/rxi/json.lua)
local json = { _version = "0.1.2" }
local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_char   = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}

local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end

local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end

local function codepoint_to_utf8(n)
  if n <= 0x7F then
    return string.char(n)
  elseif n <= 0x7FF then
    return string.char( 0xC0 + (n >> 6),
                       0x80 + (n % 0x40)
  elseif n <= 0xFFFF then
    return string.char( 0xE0 + (n >> 12),
                       0x80 + ( (n >> 6) % 0x40 ),
                       0x80 + ( n % 0x40 )
  elseif n <= 0x10FFFF then
    return string.char( 0xF0 + (n >> 18),
                       0x80 + ( (n >> 12) % 0x40 ),
                       0x80 + ( (n >> 6) % 0x40 ),
                       0x80 + ( n % 0x40 )
  else
    error( "invalid unicode codepoint" )
  end
end

parse = function(str, idx)
  idx = idx or 1
  if idx > #str then
    decode_error(str, idx, "unexpected end of input")
  end
  local chr = str:sub(idx, idx)
  if chr == '"' then
    return parse_string(str, idx)
  elseif chr == "{" then
    return parse_object(str, idx)
  elseif chr == "[" then
    return parse_array(str, idx)
  elseif space_chars[chr] then
    return parse(str, next_char(str, idx, space_chars, false))
  else
    return parse_number(str, idx)
  end
end

function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, false))
  idx = next_char(str, idx, space_chars, false)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end

return json
