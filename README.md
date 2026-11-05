# liquidtex

Liquid templates integrated into LaTeX compilation, with YAML/JSON data, inline
blocks, content-based caching, and a native Lua backend.

Released under the LaTeX Project Public License v1.3c or later.

## Quick start

Extract the package from a checkout with `make extract` (GNU Make and TeX Live).
Create `person.yml`:

```yaml
name: Oliver
```

Then compile this document with `lualatex -no-shell-escape document.tex`:

```latex
\documentclass{article}
\usepackage[engine=lua,data=person.yml]{liquidtex}
\begin{document}
Hello \liquidinline{ {{ name }} }!
\begin{liquid}
{% if name %}\textbf{ {{ name }} }{% endif %}
\end{liquid}
\end{document}
```

Keep this complete checkout alongside the document, or install the package with
`make inst`. Copying only `liquidtex.sty` is insufficient: the helper packages and
Lua files under `scripts/` are runtime dependencies.

## Rendering and data

- `\inputliquid[alias or file]{template}` renders a file.
- `\inputliquid*{template}` logs generated code without typesetting it.
- `\liquidinline[data]{expression}` renders a short, brace-balanced expression.
- The `liquid` environment captures templates verbatim, including `{% ... %}`.
- `\begin{liquiddata}{alias}` captures verbatim YAML; omitting `{alias}` replaces
  the default source. Put content and the end marker on separate lines.
- `\liquiddatasource{alias}{file}` and `data-sources={alias=file,...}` add aliases.
- `template-path={templates/,content/}` searches directories in order after the
  supplied path. Paths are relative to the compilation working directory.
- `data-files={base.yml,override.json}` recursively merges root objects in order;
  later scalars/arrays replace earlier ones. `data.pub=publications.json` adds
  the namespace `pub`. The selected default/per-call data is applied last.
- `\sectionliquid[TOC title]{template}` uses the first rendered line as the title
  and remaining lines as the section body.
- `\liquidlist[array.path]{data}{row-template}` renders each item, exposed as
  `item`, in order. Omit the optional path for a root array.

The native engine implements a **Liquid subset**, shared with the bundled
external renderer: values, paths, whitespace control, conditionals, loops,
`forloop`, and common string/list/date filters. Unsupported tags and filters raise
errors. Includes, inheritance, assignments, loop modifiers, and full Liquid
expression compatibility remain future work. Template/data text is emitted as
LaTeX; escape TeX special characters in your templates/data as needed.

## Backends and debugging

`engine=lua` uses LuaLaTeX without external processes or shell escape. The default
`engine=external` uses the bundled renderer in a `texlua` process and requires
`-shell-escape`; it also works with pdfLaTeX. To use another renderer:

```latex
\liquidsetup{engine-conf={
  path=/path/to/renderer,
  arg-style=positional,
  template-index=1,data-index=2,output-index=3
}}
```

The indices must be a permutation of 1,2,3. `arg-style=named` instead supplies
`--template=... --data=... --output=...`. `arguments={...}` adds fixed arguments
before them. Merged data is passed as generated JSON. The custom renderer must
write the output file and exit successfully. `liquidlist` uses the native/bundled
renderer; validation checks the bundled subset, not custom engine dialects.

`verbose=basic|full|trace`, `debug-dir=debug`, `diagnostics`, and `\liquidstats`
provide logs, input/output snapshots, and request/cache-hit/CPU counters.
`\liquidvalidate{template}` validates without inserting output. Lua-only custom
filters can be registered with:

```latex
\liquidfilter{shout}{function(value) return string.upper(value) .. "!" end}
```

Custom filters should be pure functions of their arguments. External state and
upvalues cannot be tracked as cache dependencies; use `no-cache` if needed.

## Cache and build integration

The default `outdir=liquidtex-cache` is resolved relative to the TeX auxiliary
output directory when `use-auxdir=true`. The visible directory name also works
with LuaTeX's default output restrictions. Hidden directories or absolute output
paths may be rejected by TeX; choose an allowed relative directory. `no-cache`
forces every request to render and bypasses persistent cache output. Inline
capture and request/result files still use the TeX auxiliary directory.

Cache identities include document, full input paths, and engine configuration;
content signatures include input contents and bundled renderer sources. Input
files are recorded for `latexmk`, and output digests in `.aux` request another run
when content changes. POSIX shell arguments support spaces/apostrophes; Windows
arguments support ordinary paths with spaces but reject shell metacharacters.
Windows end-to-end verification remains outstanding.

## CLI, tests, documentation, and installation

```sh
texlua scripts/liquidtex.lua render --template templates/cv.liquid --data data/data.yml
texlua scripts/liquidtex.lua validate --template templates/cv.liquid
texlua scripts/liquidtex.lua inspect --data data/data.yml
texlua scripts/liquidtex.lua pipeline examples/pipeline.json
make test       # Python 3, TeX Live (LuaLaTeX/pdfLaTeX/latexmk), pdftotext
make            # extract package and build the separate user manual
make inst       # install complete package in TEXMFHOME
make zip        # create source + runtime + documentation archives
```

The manual uses LuaLaTeX, latexmk, minted (with its executable), TeX documentation
packages, and shell escape. Fira fonts are optional; Latin Modern is the fallback.
`make install` targets TEXMFLOCAL; run it with the permissions appropriate to that
TeX tree. Both installation targets accept `DESTDIR` for staging. Neither invokes
sudo. Run `mktexlsr` yourself when your TeX tree requires its filename database.

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for current work and verification,
[ROADMAP.md](ROADMAP.md) for future direction, and the
[GitHub issues](https://github.com/olirwin/liquidtex/issues) for tracked requests.
