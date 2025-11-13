# `liquidtex` — Project Roadmap

This roadmap outlines the planned evolution of the `liquidtex` package.
It follows a phased approach: starting with foundational stability, then focusing on developer ergonomics, richer template support, Lua integration, deeper LaTeX interaction, and finally fully-fledged document-generation features.

Each phase can be implemented incrementally and safely.

---

# 🟦 Phase 0 — Foundation (current)

**Goal:** establish a stable backbone for template rendering.

- [ ] `.dtx` structure, installation machinery, and documentation setup
- [ ] key–value interface (`l3keys2e`)
- [ ] package options: `verbose`, `outdir`, `no-cache`, `data`
- [ ] engine selection: `external` (functional), `lua` (placeholder)
- [ ] engine configuration subkeys (`engine-conf`)
- [ ] cache directory creation
- [ ] external rendering with shell escape
- [ ] cache freshness detection using `filemod`
- [ ] public command `\inputliquid` with data override
- [ ] strict internal API naming (`__lqt_…`)

**Status:** ✔ Completed / ongoing cleanup.

---

# 🟩 Phase 1 — Developer Quality of Life

**Goal:** make debugging, tracing, and engine interactions clear and robust.

### Core features

- [ ] Clean command-line builder

  - [ ] positional argument indices
  - [ ] named argument style
  - [ ] correct quoting for spaces
  - [ ] cross-platform compatibility
- [ ] Unified logging functions (`\__lqt_log:n`)
- [ ] Verbose modes:

  - [ ] `verbose=basic`
  - [ ] `verbose=full`
  - [ ] `trace-engine`
- [ ] Forward external engine errors into LaTeX-friendly messages
- [ ] Starred form of `\inputliquid` that prints the rendered file verbatim
- [ ] Capturing stderr/stdout when possible

### Stretch goals

- [ ] “Last command” dump into `.log`
- [ ] Debug directory with intermediate outputs

---

# 🟧 Phase 2 — Richer Template Input

**Goal:** make Liquid feel like a first-class citizen in LaTeX.

### Core features

- [ ] Inline template blocks:

  ```latex
  \begin{liquid}
    {{ name }}
  \end{liquid}
  ```
- [ ] Inline template expressions:

  ```latex
  \liquidinline{ {{ user.key }} }
  ```
- [ ] Inline YAML/JSON data blocks:

  ```latex
  \begin{liquiddata}
  name: Oliver
  \end{liquiddata}
  ```
- [ ] Namespaced data sources via `data.* = …` subkeys
- [ ] Combined data merging (global + local overrides)
- [ ] Template search paths (like `\graphicspath`)

### Stretch goals

- [ ] Literal template rendering (`literal={…}`) without files
- [ ] Allow `\inputliquid` to read from stdin

---

# 🟨 Phase 3 — Lua Engine Integration

**Goal:** lightweight, portable, no shell escape required.

### Core features

- [ ] Implement `engine=lua` backend
- [ ] Bind to a Lua Liquid interpreter (existing library or embedded subset)
- [ ] Merge YAML/JSON data natively in Lua
- [ ] Cache parsed templates in Lua state
- [ ] Provide Lua-level error messages with tracebacks

### Stretch goals

- [ ] Allow rendering directly from Lua variables generated within the document
- [ ] Keep long-lived Lua VM between renders

---

# 🟫 Phase 4 — Advanced LaTeX Integration

**Goal:** dynamic content becomes natural in documents.

### Core features

- [ ] Templated document sections:

  ```latex
  \sectionliquid{title.liq}
  ```
- [ ] Templated lists / tables:

  ```latex
  \liquidlist{pubs.yml}{pub-row.liq}
  ```
- [ ] Automatic multi-run detection

  - [ ] write sentinel files
  - [ ] cooperate with latexmk/arara
- [ ] Automatic dependency tracking (template + data)
- [ ] `filecontents`-style generated `.tex` files via templates

### Stretch goals

- [ ] Automatic rerun of Liquid layer within complex workflows
- [ ] Dedicated `.lqt` template modules

---

# 🟪 Phase 5 — Toolkit-Level Features

**Goal:** make `liquidtex` a complete data-driven document system.

### Core features

- [ ] Custom Liquid filters defined in LaTeX:

  ```latex
  \liquidfilter{uppercase}{...}
  ```
- [ ] Template partials and inheritance
- [ ] Robust validation tools:

  ```latex
  \liquidvalidate{template.liq}
  ```
- [ ] Diagnostics:

  - [ ] number of cache hits
  - [ ] performance measurements
  - [ ] dependency graphs

### Stretch goals

- [ ] Templated TikZ diagrams
- [ ] Templated bibliography entries (`biblatex` integration)

---

# 🟦 Phase 6 — Fully Integrated Workflow System

**Goal:** from package → framework.

### Possible features

- [ ] Automatic generation of CVs, syllabi, publication lists
- [ ] Multi-template pipelines
- [ ] Integrated dataset management
- [ ] Optional CLI companion for testing templates outside of LaTeX
- [ ] Unified “liquid project” configuration file
- [ ] Export LaTeX+Liquid templates into standalone build artifacts
- [ ] HTML output pipeline via Liquid → LaTeX → PDF → HTML → Markdown

---

