-- Internal TeX-to-runtime bridge. LPPL 1.3c or later.
local directory = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "./"
local runtime = dofile(directory .. "lqt_runtime.lua")
local ok = runtime.run_file(assert(arg[1], "missing request file"))
os.exit(ok and 0 or 1)
