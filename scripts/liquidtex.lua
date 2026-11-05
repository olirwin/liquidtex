-- LiquidTeX companion CLI. Run with texlua; LPPL 1.3c or later.
local directory = arg[0]:match("^(.*[/\\])") or "./"
local runtime = dofile(directory .. "lqt_runtime.lua")
local json, lfs = runtime.engine.json, require("lfs")
local function usage()
  print([[LiquidTeX
  texlua scripts/liquidtex.lua render --template FILE [--data FILE] [--output FILE]
  texlua scripts/liquidtex.lua validate --template FILE [--data FILE]
  texlua scripts/liquidtex.lua inspect --data FILE [--data-file FILE ...]
  texlua scripts/liquidtex.lua pipeline CONFIG.json|CONFIG.yml
  texlua scripts/liquidtex.lua TEMPLATE DATA OUTPUT   (positional renderer)

Options: --data-file FILE (repeatable, merged before --data), --outdir DIR,
         --no-cache, --debug-dir DIR. Pipelines use paths relative to CONFIG.
The renderer supports a documented Liquid subset; it is not a full Liquid VM.]])
end
local function main()
  if not arg[1] or arg[1] == "--help" or arg[1] == "help" then usage(); return end
  local action = arg[1]
  local opts = {action = action, data_files = {}, no_cache = true, data_path = ""}
  local output
  if action == "pipeline" then
    assert(arg[2], "pipeline requires a configuration file")
    local config = runtime.engine.load_data(arg[2])
    assert(type(config.outputs) == "table" and #config.outputs > 0, "pipeline requires an outputs array")
    local original = lfs.currentdir()
    assert(lfs.chdir(runtime.dirname(arg[2])))
    local seen = {}
    for _, job in ipairs(config.outputs) do
      assert(type(job.template) == "string" and type(job.output) == "string", "each pipeline output requires template and output")
      assert(not seen[job.output], "duplicate pipeline output: " .. job.output); seen[job.output] = true
      local request = {
        template_path = job.template, data_path = job.data or config.data or "",
        data_files = job.data_files or config.data_files or {},
        namespaces = job.namespaces or config.namespaces or {},
        document = job.output, outdir = config.outdir or "liquidtex-cache",
        no_cache = config.no_cache == true, use_auxdir = false,
      }
      local result = runtime.process(request)
      if runtime.read(job.output, true) ~= result.output then runtime.write(job.output, result.output) end
      print(job.output .. (result.cache_hit and ": cached" or ": rendered"))
    end
    assert(lfs.chdir(original)); return
  elseif action ~= "render" and action ~= "validate" and action ~= "inspect" then
    assert(arg[2] and arg[3] and not arg[4], "unknown command; use --help")
    opts.template_path, opts.data_path, output, opts.action = arg[1], arg[2], arg[3], "render"
  else
    local i = 2
    while i <= #arg do
      local key, value = arg[i]:match("^%-%-([%w%-]+)=(.*)$")
      if not key then key = arg[i]:match("^%-%-([%w%-]+)$") end
      assert(key, "invalid option: " .. arg[i])
      if key == "no-cache" then opts.no_cache = true
      elseif key == "cache" then opts.no_cache = false
      else
        if not value then i = i + 1; value = assert(arg[i], "missing value for --" .. key) end
        if key == "template" then opts.template_path = value
        elseif key == "data" then opts.data_path = value
        elseif key == "output" then output = value
        elseif key == "outdir" then opts.outdir = value
        elseif key == "debug-dir" then opts.debug_dir = value
        elseif key == "data-file" then opts.data_files[#opts.data_files + 1] = value
        else error("unknown option: --" .. key, 0) end
      end
      i = i + 1
    end
  end
  if opts.action == "inspect" then print(runtime.canonical(runtime.data(opts))); return end
  assert(opts.template_path, "--template is required")
  if opts.action == "validate" then
    runtime.process(opts); print("Valid: " .. opts.template_path); return
  end
  local result = runtime.process(opts)
  if output then runtime.write(output, result.output) else io.write(result.output) end
end
local ok, err = xpcall(main, debug.traceback)
if not ok then io.stderr:write("liquidtex: " .. tostring(err) .. "\n"); os.exit(1) end
