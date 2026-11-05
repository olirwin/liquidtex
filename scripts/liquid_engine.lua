-- liquid_engine.lua
-- Minimal Liquid renderer for LuaTeX.
local source = debug.getinfo and debug.getinfo(1, "S").source:sub(2) or ...
local directory = assert(source, "module path is required"):match("^(.*[/\\])") or "./"
local json = dofile(directory .. "json.lua")
local yaml = dofile(directory .. "yaml.lua")

local M = {}
local unpack = table.unpack or unpack

local EMPTY = {}

local function read_file(path)
  if not path or path == "" then
    return nil, "empty path"
  end
  local handle, err = io.open(path, "rb")
  if not handle then
    return nil, err
  end
  local data = handle:read("*a")
  handle:close()
  return data
end

local function write_file(path, data)
  local handle, err = io.open(path, "wb")
  if not handle then
    return nil, err
  end
  handle:write(data)
  handle:close()
  return true
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_unquoted(s, sep)
  local out = {}
  local buf = {}
  local i = 1
  local quote = nil
  while i <= #s do
    local c = s:sub(i, i)
    if quote then
      if c == "\\" and i < #s then
        buf[#buf + 1] = c
        i = i + 1
        buf[#buf + 1] = s:sub(i, i)
      elseif c == quote then
        quote = nil
        buf[#buf + 1] = c
      else
        buf[#buf + 1] = c
      end
    else
      if c == "'" or c == "\"" then
        quote = c
        buf[#buf + 1] = c
      elseif c == sep then
        out[#out + 1] = table.concat(buf)
        buf = {}
      else
        buf[#buf + 1] = c
      end
    end
    i = i + 1
  end
  if quote then error("unterminated quoted string", 0) end
  out[#out + 1] = table.concat(buf)
  return out
end

local function parse_quoted(s)
  local quote = s:sub(1, 1)
  if quote ~= "'" and quote ~= "\"" then
    return s
  end
  local out = {}
  local i = 2
  while i <= #s do
    local c = s:sub(i, i)
    if c == "\\" and i < #s then
      out[#out + 1] = s:sub(i + 1, i + 1)
      i = i + 2
    elseif c == quote then
      break
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

local function tokenize_expr(s)
  local tokens = {}
  local i = 1
  local len = #s
  while i <= len do
    local c = s:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c == "'" or c == "\"" then
      local quote = c
      i = i + 1
      local buf = {}
      while i <= len do
        local ch = s:sub(i, i)
        if ch == "\\" and i < len then
          buf[#buf + 1] = s:sub(i + 1, i + 1)
          i = i + 2
        elseif ch == quote then
          i = i + 1
          break
        else
          buf[#buf + 1] = ch
          i = i + 1
        end
      end
      tokens[#tokens + 1] = { type = "string", value = table.concat(buf) }
    else
      local two = s:sub(i, i + 1)
      if two == "==" or two == "!=" or two == ">=" or two == "<=" then
        tokens[#tokens + 1] = { type = "op", value = two }
        i = i + 2
      elseif c == ">" or c == "<" then
        tokens[#tokens + 1] = { type = "op", value = c }
        i = i + 1
      else
        local j = i
        while j <= len do
          local ch = s:sub(j, j)
          if ch:match("%s") then
            break
          end
          if ch == ">" or ch == "<" or ch == "=" or ch == "!" then
            break
          end
          j = j + 1
        end
        if j == i then error("unexpected expression character: " .. c) end
        tokens[#tokens + 1] = { type = "word", value = s:sub(i, j - 1) }
        i = j
      end
    end
  end
  return tokens
end

local function parse_path(path)
  local parts = {}
  local i = 1
  local len = #path

  local function read_ident()
    local start = i
    while i <= len do
      local c = path:sub(i, i)
      if c:match("[%w_%-]") then
        i = i + 1
      else
        break
      end
    end
    if i > start then
      parts[#parts + 1] = path:sub(start, i - 1)
      return true
    end
    return false
  end

  local function read_bracket()
    if path:sub(i, i) ~= "[" then
      return false
    end
    i = i + 1
    while i <= len and path:sub(i, i):match("%s") do
      i = i + 1
    end
    local c = path:sub(i, i)
    local key
    if c == "'" or c == "\"" then
      local quote = c
      i = i + 1
      local buf = {}
      while i <= len do
        local ch = path:sub(i, i)
        if ch == "\\" and i < len then
          buf[#buf + 1] = path:sub(i + 1, i + 1)
          i = i + 2
        elseif ch == quote then
          i = i + 1
          break
        else
          buf[#buf + 1] = ch
          i = i + 1
        end
      end
      key = table.concat(buf)
    else
      local start = i
      while i <= len and path:sub(i, i) ~= "]" do
        i = i + 1
      end
      key = trim(path:sub(start, i - 1))
      local num = tonumber(key)
      if num then
        key = num
      end
    end
    while i <= len and path:sub(i, i) ~= "]" do
      i = i + 1
    end
    if path:sub(i, i) == "]" then
      i = i + 1
    end
    parts[#parts + 1] = key
    return true
  end

  read_ident()
  while i <= len do
    local c = path:sub(i, i)
    if c == "." then
      i = i + 1
      read_ident()
    elseif c == "[" then
      read_bracket()
    else
      i = i + 1
    end
  end
  return parts
end

local function resolve_path(ctx, path)
  if path == "" then
    return nil
  end
  local parts = parse_path(path)
  local value = ctx
  for _, key in ipairs(parts) do
    if type(value) ~= "table" then
      return nil
    end
    if type(key) == "number" then
      value = value[key + 1]
    elseif key == "size" and rawget(value, key) == nil then
      value = #value
    elseif key == "first" and rawget(value, key) == nil then
      value = value[1]
    elseif key == "last" and rawget(value, key) == nil then
      value = value[#value]
    else
      value = value[key]
    end
  end
  return value
end

local function eval_value(expr, ctx)
  expr = trim(expr)
  if expr == "" then
    return nil
  end
  local first = expr:sub(1, 1)
  if first == "'" or first == "\"" then
    return parse_quoted(expr)
  end
  if expr == "true" then
    return true
  end
  if expr == "false" then
    return false
  end
  if expr == "nil" or expr == "null" then
    return nil
  end
  if expr == "empty" then
    return EMPTY
  end
  local num = tonumber(expr)
  if num then
    return num
  end
  return resolve_path(ctx, expr)
end

local function is_empty(value)
  if value == EMPTY then
    return true
  end
  if value == nil then
    return true
  end
  if type(value) == "string" then
    return value == ""
  end
  if type(value) == "table" then
    return next(value) == nil
  end
  return false
end

local function truthy(value)
  return not (value == nil or value == false)
end

local function compare(op, left, right)
  if op == "==" then
    if left == EMPTY then
      return is_empty(right)
    end
    if right == EMPTY then
      return is_empty(left)
    end
    return left == right
  end
  if op == "!=" then
    if left == EMPTY then
      return not is_empty(right)
    end
    if right == EMPTY then
      return not is_empty(left)
    end
    return left ~= right
  end
  if op == ">" then
    return left > right
  end
  if op == "<" then
    return left < right
  end
  if op == ">=" then
    return left >= right
  end
  if op == "<=" then
    return left <= right
  end
  if op == "contains" then
    if type(left) == "string" then
      return tostring(left):find(tostring(right), 1, true) ~= nil
    end
    if type(left) == "table" then
      for _, v in pairs(left) do
        if v == right then
          return true
        end
      end
    end
    return false
  end
  return false
end

local function eval_expr(expr, ctx, validation)
  local tokens = tokenize_expr(expr)
  local pos = 1

  local function peek()
    return tokens[pos]
  end

  local function consume()
    local tok = tokens[pos]
    pos = pos + 1
    return tok
  end

  local function peek_word(word)
    local tok = peek()
    return tok and tok.type == "word" and tok.value == word
  end

  local function parse_value_token()
    local tok = consume()
    if not tok then error("missing expression operand", 0) end
    if tok.type == "string" then
      return tok.value
    end
    if tok.type == "word" then
      return eval_value(tok.value, ctx)
    end
    error("expected expression operand", 0)
  end

  local function parse_comparison()
    local left = parse_value_token()
    local tok = peek()
    if tok and tok.type == "op" then
      consume()
      local right = parse_value_token()
      return validation or compare(tok.value, left, right)
    end
    if tok and tok.type == "word" and tok.value == "contains" then
      consume()
      local right = parse_value_token()
      return validation or compare("contains", left, right)
    end
    return left
  end

  local function parse_not()
    if peek_word("not") then
      consume()
      return not truthy(parse_not())
    end
    return parse_comparison()
  end

  local function parse_and()
    local left = parse_not()
    while peek_word("and") do
      consume()
      local right = parse_not()
      left = truthy(left) and truthy(right)
    end
    return left
  end

  local function parse_or()
    local left = parse_and()
    while peek_word("or") do
      consume()
      local right = parse_and()
      left = truthy(left) or truthy(right)
    end
    return left
  end

  local result = truthy(parse_or())
  if pos <= #tokens then error("unexpected expression token: " .. tokens[pos].value) end
  return result
end

local filters = {}

filters.upcase = function(value)
  return tostring(value):upper()
end

filters.downcase = function(value)
  return tostring(value):lower()
end

filters.capitalize = function(value)
  local s = tostring(value)
  return s:sub(1, 1):upper() .. s:sub(2):lower()
end

filters.strip = function(value)
  return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

filters.strip_newlines = function(value)
  return tostring(value):gsub("\n", "")
end

filters.append = function(value, arg)
  return tostring(value) .. tostring(arg or "")
end

filters.prepend = function(value, arg)
  return tostring(arg or "") .. tostring(value)
end

local function replace_literal(value, search, replacement, limit)
  local pattern = tostring(search or ""):gsub("([^%w])", "%%%1")
  local result = tostring(value or ""):gsub(pattern, function() return tostring(replacement or "") end, limit)
  return result
end
filters.replace = function(value, a, b) return replace_literal(value, a, b) end
filters.replace_first = function(value, a, b) return replace_literal(value, a, b, 1) end

filters.default = function(value, arg)
  if value == nil or value == "" or value == false then
    return arg
  end
  return value
end

filters.size = function(value)
  if type(value) == "string" then
    return #value
  end
  if type(value) == "table" then
    return #value
  end
  return 0
end

filters.join = function(value, sep)
  if type(value) ~= "table" then
    return value
  end
  return table.concat(value, sep or "")
end

filters.split = function(value, sep)
  local s = tostring(value)
  sep = tostring(sep or "")
  if sep == "" then
    local out = {}
    for i = 1, #s do
      out[#out + 1] = s:sub(i, i)
    end
    return out
  end
  local out = {}
  local start = 1
  while true do
    local pos = s:find(sep, start, true)
    if not pos then
      out[#out + 1] = s:sub(start)
      break
    end
    out[#out + 1] = s:sub(start, pos - 1)
    start = pos + #sep
  end
  return out
end

local function parse_date_value(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" then
    local s = trim(value)
    if s == "" then
      return nil
    end
    if s == "now" or s == "today" then
      return os.time()
    end
    local y, m, d, hh, mm, ss
    y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if y then
      return os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = 0,
        min = 0,
        sec = 0,
      })
    end
    y, m, d, hh, mm, ss = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[ T](%d%d):(%d%d):(%d%d)$")
    if y then
      return os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(hh),
        min = tonumber(mm),
        sec = tonumber(ss),
      })
    end
    y, m, d, hh, mm = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[ T](%d%d):(%d%d)$")
    if y then
      return os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(hh),
        min = tonumber(mm),
        sec = 0,
      })
    end
  end
  return nil
end

filters.date = function(value, format)
  if value == nil then
    return ""
  end
  local ts = parse_date_value(value)
  if not ts then
    return tostring(value)
  end
  local fmt = "%Y-%m-%d"
  if format ~= nil then
    fmt = tostring(format)
  end
  return os.date(fmt, ts)
end

local function apply_filter(name, value, args)
  local filter = filters[name]
  if not filter then
    error("unknown filter: " .. tostring(name))
  end
  return filter(value, unpack(args or {}))
end

local function eval_output(expr, ctx)
  local parts = split_unquoted(expr, "|")
  local base = trim(parts[1] or "")
  local value = eval_value(base, ctx)
  for i = 2, #parts do
    local filter_str = trim(parts[i])
    if filter_str ~= "" then
      local fname, arg_str = filter_str:match("^([%w_]+)%s*:%s*(.*)$")
      if not fname then
        fname = filter_str
        arg_str = nil
      end
      local args = {}
      if arg_str and arg_str ~= "" then
        local raw_args = split_unquoted(arg_str, ",")
        for _, a in ipairs(raw_args) do
          args[#args + 1] = eval_value(trim(a), ctx)
        end
      end
      value = apply_filter(fname, value, args)
    end
  end
  if value == nil or value == EMPTY then
    return ""
  end
  return tostring(value)
end

local function validate_output(expression)
  local parts = split_unquoted(expression, "|")
  if trim(parts[1] or "") == "" then error("empty output expression", 0) end
  for i = 2, #parts do
    local name, args = trim(parts[i]):match("^([%w_]+)%s*:%s*(.*)$")
    if not name then name = trim(parts[i]) end
    if not filters[name] then error("unknown filter: " .. name, 0) end
    if args then
      for _, arg in ipairs(split_unquoted(args, ",")) do
        if trim(arg) == "" then error("missing filter argument: " .. name, 0) end
      end
    end
  end
end

local function parse_template(template)
  local nodes = {}
  local stack = { { kind = "root", body = nodes } }
  local current, i, strip_next = nodes, 1, false
  local function location(pos)
    local _, count = template:sub(1, pos - 1):gsub("\n", "")
    return count + 1
  end
  local function fail(message, pos)
    error("line " .. location(pos or i) .. ": " .. message, 0)
  end
  local function text_node(text, trim_right)
    if strip_next then text = text:gsub("^%s+", ""); strip_next = false end
    if trim_right then text = text:gsub("%s+$", "") end
    if text ~= "" then current[#current + 1] = { type = "text", value = text } end
  end
  while i <= #template do
    local next_out = template:find("{{", i, true)
    local next_tag = template:find("{%", i, true)
    local pos = next_out and next_tag and math.min(next_out, next_tag) or next_out or next_tag
    if not pos then text_node(template:sub(i)); break end
    local trim_left = template:sub(pos + 2, pos + 2) == "-"
    text_node(template:sub(i, pos - 1), trim_left)
    if trim_left and current[#current] and current[#current].type == "text" then
      current[#current].value = current[#current].value:gsub("%s+$", "")
    end
    local output = pos == next_out
    local close = template:find(output and "}}" or "%}", pos + 2, true)
    if not close then fail(output and "unclosed output tag" or "unclosed tag", pos) end
    local trim_right = template:sub(close - 1, close - 1) == "-"
    local content = trim(template:sub(pos + (trim_left and 3 or 2), close - (trim_right and 2 or 1)))
    local line = location(pos)
    if output then
      local ok, err = pcall(validate_output, content)
      if not ok then fail(tostring(err), pos) end
      current[#current + 1] = { type = "output", expr = content, line = line }
    elseif content:match("^if%s+") then
      local ok, err = pcall(eval_expr, trim(content:sub(3)), {}, true)
      if not ok then fail(tostring(err), pos) end
      local node = { type = "if", branches = { { cond = trim(content:sub(3)), body = {} } }, line = line }
      current[#current + 1] = node
      stack[#stack + 1] = { kind = "if", node = node, body = current, line = line }
      current = node.branches[1].body
    elseif content:match("^elsif%s+") then
      local top = stack[#stack]
      if top.kind ~= "if" or top.node.else_body then fail("elsif without if, or after else", pos) end
      local ok, err = pcall(eval_expr, trim(content:sub(6)), {}, true)
      if not ok then fail(tostring(err), pos) end
      top.node.branches[#top.node.branches + 1] = { cond = trim(content:sub(6)), body = {} }
      current = top.node.branches[#top.node.branches].body
    elseif content == "else" then
      local top = stack[#stack]
      if top.kind ~= "if" or top.node.else_body then fail("else without if, or duplicate else", pos) end
      top.node.else_body = {}; current = top.node.else_body
    elseif content == "endif" or content == "endfor" then
      local top = stack[#stack]
      if top.kind ~= (content == "endif" and "if" or "for") then fail("unexpected " .. content, pos) end
      current = top.body; stack[#stack] = nil
    elseif content:match("^for%s+") then
      local var, expr = content:match("^for%s+([%w_%-]+)%s+in%s+(.+)$")
      if not var then fail("invalid for tag", pos) end
      local node = { type = "for", var = var, expr = trim(expr), body = {}, line = line }
      current[#current + 1] = node
      stack[#stack + 1] = { kind = "for", node = node, body = current, line = line }
      current = node.body
    else
      fail("unknown tag: " .. content, pos)
    end
    i = close + 2; strip_next = trim_right
  end
  if #stack > 1 then fail("unclosed block: " .. stack[#stack].kind, #template + 1) end
  return nodes
end

local function render_nodes(nodes, ctx)
  local out = {}
  for _, node in ipairs(nodes) do
    local ok, err = pcall(function()
    if node.type == "text" then
      out[#out + 1] = node.value
    elseif node.type == "output" then
      out[#out + 1] = eval_output(node.expr, ctx)
    elseif node.type == "if" then
      local rendered = false
      for _, branch in ipairs(node.branches) do
        if eval_expr(branch.cond, ctx) then
          out[#out + 1] = render_nodes(branch.body, ctx)
          rendered = true
          break
        end
      end
      if not rendered and node.else_body then
        out[#out + 1] = render_nodes(node.else_body, ctx)
      end
    elseif node.type == "for" then
      local list = eval_value(node.expr, ctx)
      if type(list) == "table" then
        local is_array = #list > 0
        if is_array then
          for index, item in ipairs(list) do
            local scope = setmetatable({ [node.var] = item,
              forloop = {index = index, index0 = index - 1, first = index == 1, last = index == #list, length = #list}
            }, { __index = ctx })
            out[#out + 1] = render_nodes(node.body, scope)
          end
        else
          local keys = {}
          for key in pairs(list) do keys[#keys + 1] = key end
          table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
          for _, key in ipairs(keys) do
            local scope = setmetatable({ [node.var] = {key, list[key]} }, { __index = ctx })
            out[#out + 1] = render_nodes(node.body, scope)
          end
        end
      end
    end
    end)
    if not ok then error("line " .. (node.line or 1) .. ": " .. tostring(err), 0) end
  end
  return table.concat(out)
end

local function load_data(path)
  if not path or path == "" then return {} end
  local content, err = read_file(path)
  if not content then error("data file " .. path .. ": " .. tostring(err), 0) end
  local ok, data = pcall(function()
    if path:lower():match("%.json$") then return json.decode(content) end
    return yaml.eval(content)
  end)
  if not ok then error("data file " .. path .. ": " .. tostring(data), 0) end
  if type(data) ~= "table" then error("data file " .. path .. ": expected an object or array", 0) end
  return data
end

local parsed = {}
function M.compile(template)
  if not parsed[template] then parsed[template] = parse_template(template) end
  return parsed[template]
end
function M.render_text(template, data, path)
  local ok, result = xpcall(function() return render_nodes(M.compile(template), data or {}) end, debug.traceback)
  if not ok then error((path or "<inline>") .. ": " .. tostring(result), 0) end
  return result
end
function M.validate(template, path)
  local ok, err = pcall(M.compile, template)
  if not ok then error((path or "<inline>") .. ": " .. tostring(err), 0) end
  return true
end
function M.is_array(value)
  if type(value) ~= "table" then return false end
  local mt = getmetatable(value)
  return #value > 0 or mt == json.array_metatable or mt == yaml.array_metatable
end
M.load_data = load_data
M.resolve_path = resolve_path
M.json = json
M.filter_versions = {}
function M.register_filter(name, implementation)
  assert(type(name) == "string" and name:match("^[%a_][%w_]*$"), "invalid filter name")
  assert(type(implementation) == "function", "filter implementation must be a function")
  filters[name] = implementation
  M.filter_versions[name] = string.dump(implementation)
end
function M.render(opts)
  local ok, result = xpcall(function()
    local template = opts.template_string
    if not template then
      local err
      template, err = read_file(opts.template_path)
      if not template then error("template file " .. tostring(opts.template_path) .. ": " .. tostring(err), 0) end
    end
    local data = opts.data or load_data(opts.data_path)
    local output = M.render_text(template, data, opts.template_path)
    if opts.output_path then assert(write_file(opts.output_path, output)) end
    if opts.to_tex then assert(tex and tex.sprint, "direct TeX output requires LuaTeX"); tex.sprint(output) end
    return output
  end, debug.traceback)
  if not ok then return nil, result end
  return true, result
end
return M
