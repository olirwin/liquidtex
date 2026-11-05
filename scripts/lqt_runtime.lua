-- Shared native/CLI runtime. LPPL 1.3c or later; Oliver Irwin and contributors.
local source = debug.getinfo and debug.getinfo(1, "S").source:sub(2) or ...
local directory = assert(source, "module path is required"):match("^(.*[/\\])") or "./"
local engine = assert(loadfile(directory .. "liquid_engine.lua"))(directory .. "liquid_engine.lua")
local json = engine.json
local lfs = require("lfs")
local digest = md5 or require("md5")
local M = { engine = engine }

local function read(path, optional)
  local f, err = io.open(path, "rb")
  if not f then
    if optional then return nil end
    error(tostring(path) .. ": " .. tostring(err), 0)
  end
  local value = f:read("*a"); f:close(); return value
end
local function dirname(path) return path:match("^(.*)[/\\][^/\\]*$") or "." end
local function absolute(path)
  return path:sub(1, 1) == "/" or path:match("^%a:[/\\]") or path:sub(1, 2) == "\\\\"
end
local function join(base, path)
  if absolute(path) then return path end
  return base .. "/" .. path
end
local function mkdir(path)
  if path == "" or path == "." or lfs.attributes(path, "mode") == "directory" then return end
  local parent = dirname(path)
  if parent ~= path then mkdir(parent) end
  local ok, err = lfs.mkdir(path)
  if not ok and lfs.attributes(path, "mode") ~= "directory" then error(tostring(err), 0) end
end
local function write(path, value)
  mkdir(dirname(path))
  local f, err = io.open(path, "wb"); assert(f, "cannot write " .. path .. ": " .. tostring(err or "blocked by TeX output restrictions"))
  assert(f:write(value)); assert(f:close())
end
local function canonical(value)
  if type(value) ~= "table" then return json.encode(value) end
  if engine.is_array(value) then
    local out = {}; for i, v in ipairs(value) do out[i] = canonical(v) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  local keys, out = {}, {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do out[#out + 1] = json.encode(key) .. ":" .. canonical(value[key]) end
  return "{" .. table.concat(out, ",") .. "}"
end
local function hash(value) return digest.sumhexa(value) end
local function is_array(value) return engine.is_array(value) end
local function merge(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" and type(target[key]) == "table"
        and not is_array(value) and not is_array(target[key]) then
      merge(target[key], value)
    else target[key] = value end
  end
  return target
end
local function object(data, path)
  if is_array(data) then error("data file " .. path .. ": expected an object for merging", 0) end
  return data
end
function M.data(opts)
  local combined, dependencies = {}, {}
  local function load(path)
    dependencies[#dependencies + 1] = {path = join(lfs.currentdir(), path), content = read(path)}
    return engine.load_data(path)
  end
  for _, path in ipairs(opts.data_files or {}) do merge(combined, object(load(path), path)) end
  local namespaces = {}
  for name in pairs(opts.namespaces or {}) do namespaces[#namespaces + 1] = name end
  table.sort(namespaces)
  for _, name in ipairs(namespaces) do combined[name] = load(opts.namespaces[name]) end
  if opts.data_path and opts.data_path ~= "" then
    local selected = load(opts.data_path)
    if #dependencies == 1 then combined = selected
    else merge(combined, object(selected, opts.data_path)) end
  end
  return combined, dependencies
end

-- One shell builder is used for both renderer invocation and the TeX bridge.
function M.quote(value, windows)
  value = tostring(value)
  assert(not value:find("[\r\n%z]"), "newlines/NUL are not supported in shell arguments")
  if windows == nil then windows = package.config:sub(1, 1) == "\\" end
  if windows then
    assert(not value:find('[%%!"&|<>^]'), "unsupported Windows shell metacharacter in argument")
    return '"' .. value:gsub('(\\+)$', '%1%1') .. '"'
  end
  return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end
function M.command(opts, template, data, output)
  local args = {M.quote(opts.path)}
  for _, arg in ipairs(opts.arguments or {}) do args[#args + 1] = M.quote(arg) end
  if opts.arg_style == "named" then
    for _, pair in ipairs({{"template", template}, {"data", data}, {"output", output}}) do
      args[#args + 1] = M.quote("--" .. pair[1] .. "=" .. pair[2])
    end
  else
    local positions, seen = {}, {}
    for _, pair in ipairs({{opts.template_index or 1, template}, {opts.data_index or 2, data}, {opts.output_index or 3, output}}) do
      assert(pair[1] >= 1 and pair[1] <= 3 and pair[1] % 1 == 0 and not seen[pair[1]],
        "template-index, data-index and output-index must be a permutation of 1,2,3")
      positions[pair[1]], seen[pair[1]] = pair[2], true
    end
    for _, arg in ipairs(positions) do args[#args + 1] = M.quote(arg) end
  end
  return table.concat(args, " ")
end
local source_signature = ""
for _, filename in ipairs({"lqt_runtime.lua", "liquid_engine.lua", "json.lua", "yaml.lua"}) do
  source_signature = source_signature .. read(directory .. filename)
end
source_signature = hash(source_signature)

function M.process(opts)
  local started = os.clock()
  local template = read(opts.template_path)
  if opts.action == "validate" then
    engine.validate(template, opts.template_path)
    if opts.data_path ~= "" or #(opts.data_files or {}) > 0 or next(opts.namespaces or {}) then M.data(opts) end
    return {validated = true}
  end
  local data, dependencies = M.data(opts)
  local base = opts.auxdir or "."
  local cache = opts.outdir or "liquidtex-cache"
  if opts.use_auxdir ~= false then cache = join(base, cache) end
  if not opts.no_cache or (opts.external and opts.external.path ~= "") then mkdir(cache) end
  local identity = {
    document = join(lfs.currentdir(), opts.document or "cli"),
    template = join(lfs.currentdir(), opts.template_path),
    data_path = opts.data_path or "", data_files = opts.data_files or {},
    namespaces = opts.namespaces or {}, external = opts.external or {},
    action = opts.action or "render", array_key = opts.array_key or "", section_toc = opts.section_toc or "",
  }
  local key = hash(canonical(identity))
  local output_path = cache .. "/" .. key .. ".tex"
  local signature_path = cache .. "/" .. key .. ".sig"
  local signature = hash(canonical({identity, template, dependencies, source_signature, engine.filter_versions}))
  local old = read(output_path, true)
  local hit = not opts.no_cache and old ~= nil and read(signature_path, true) == signature
  local output, command = old, ""
  local log_path = cache .. "/" .. key .. ".log"
  if not hit then
    if opts.external and opts.external.path and opts.external.path ~= "" then
      assert(opts.action ~= "list", "liquidlist requires the native or bundled renderer")
      local data_path = opts.data_path or ""
      if #(opts.data_files or {}) > 0 or next(opts.namespaces or {}) then
        data_path = cache .. "/" .. key .. ".data.json"
        write(data_path, canonical(data))
      end
      local temporary = output_path .. ".tmp"
      os.remove(temporary)
      command = M.command(opts.external, opts.template_path, data_path, temporary)
      local ok, reason, code = os.execute(command .. " > " .. M.quote(log_path) .. " 2>&1")
      if ok ~= true and ok ~= 0 then
        if type(ok) == "number" and reason == nil then
          code = package.config:sub(1, 1) == "\\" and ok or math.floor(ok / 256)
          reason = "exit"
        end
        error("external renderer failed (" .. tostring(reason) .. " " .. tostring(code or ok) .. ")\nCommand: " .. command .. "\n" .. (read(log_path, true) or ""), 0)
      end
      output = read(temporary, true)
      if not output then error("external renderer produced no output\nCommand: " .. command .. "\n" .. (read(log_path, true) or ""), 0) end
      os.remove(temporary)
    elseif opts.action == "list" then
      local array = opts.array_key and opts.array_key ~= "" and engine.resolve_path(data, opts.array_key) or data
      assert(engine.is_array(array), "liquidlist expected an array at " .. (opts.array_key or "<root>"))
      output = {}
      for index, item in ipairs(array) do
        local context = setmetatable({item = item, forloop = {index = index, index0 = index - 1, first = index == 1, last = index == #array, length = #array}}, {__index = data})
        output[#output + 1] = engine.render_text(template, context, opts.template_path)
      end
      output = table.concat(output)
      if not opts.no_cache then write(log_path, "") end
    else
      output = engine.render_text(template, data, opts.template_path)
      if not opts.no_cache then write(log_path, "") end
    end
    if opts.action == "section" then
      local title, body = output:match("^%s*([^\r\n]+)\r?\n?(.*)$")
      assert(title, "sectionliquid requires a nonempty title on the first rendered line")
      local toc = opts.section_toc and opts.section_toc ~= "" and ("[" .. opts.section_toc .. "]") or ""
      output = "\\section" .. toc .. "{" .. title .. "}\n" .. body
    end
    -- Publish only successful results. A failed renderer cannot reuse stale output.
    if not opts.no_cache then
      write(output_path, output)
      write(signature_path, signature)
    end
  end
  if opts.debug_dir and opts.debug_dir ~= "" then
    local debug_dir = opts.use_auxdir ~= false and join(base, opts.debug_dir) or opts.debug_dir
    local prefix = debug_dir .. "/" .. key
    write(prefix .. ".liquid", template)
    write(prefix .. ".data.json", canonical(data))
    write(prefix .. ".tex", output)
    write(prefix .. ".log", read(log_path, true) or "")
  end
  return {output = output, output_path = output_path, key = key, digest = hash(output),
    cache_hit = hit, changed = old ~= output, duration = os.clock() - started, command = command}
end

-- Result files contain fixed TeX commands and numeric/hex values only.
function M.run_file(request_path)
  if not lfs.attributes(request_path) then
    local output_dir = (status and status.output_directory) or os.getenv("TEXMF_OUTPUT_DIRECTORY")
    -- LuaTeX before TeX Live 2024 does not expose either of those values.
    if not output_dir or output_dir == "" then
      for index, value in ipairs(arg or {}) do
        local option = value:match("^%-%-?output%-directory=(.*)$")
        if option then output_dir = option end
        if value == "-output-directory" or value == "--output-directory" then
          output_dir = arg[index + 1]
        end
      end
    end
    if output_dir and output_dir ~= "" then request_path = join(output_dir, request_path) end
  end
  local result_path = request_path:gsub("%.json$", ".result.tex")
  local output_path = request_path:gsub("%.json$", ".output.tex")
  local log_path = request_path:gsub("%.json$", ".log")
  local ok, result = xpcall(function()
    local opts = json.decode(read(request_path))
    opts.auxdir = dirname(request_path)
    local result = M.process(opts)
    if not result.validated then
      write(output_path, result.output)
      write(log_path, result.command ~= "" and ("Command: " .. result.command .. "\n") or "")
    else write(log_path, "Template validation passed.\n") end
    return result
  end, debug.traceback)
  if ok then
    if result.validated then write(result_path, "\\liquidtexvalidated{}\n")
    else write(result_path, string.format("\\liquidtexresult{%d}{%.6f}{%s}{%s}\n", result.cache_hit and 1 or 0, result.duration, result.key, result.digest)) end
  else
    write(log_path, tostring(result) .. "\n")
    write(result_path, "\\liquidtexfailure{}\n")
  end
  return ok, result
end

M.read, M.write, M.canonical, M.hash, M.merge = read, write, canonical, hash, merge
M.dirname, M.join, M.mkdir = dirname, join, mkdir
return M
