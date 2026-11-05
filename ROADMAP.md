# liquidtex roadmap

Updated 2026-11-05 for the `fix/reproducible-rendering` branch. Implemented items
are pending review/merge; see [PROJECT_STATUS.md](PROJECT_STATUS.md) for evidence
and GitHub links. The original phase ordering is retained below.

## Phase 0 — Foundation

- [x] DocStrip sources, public configuration, helper modules.
- [x] Restore loading under LuaLaTeX and pdfLaTeX.
- [x] Track runtime libraries and fixtures; build the actual user manual.
- [x] Complete TeX-tree installation and archive contents; consistent 0.3.0 metadata.
- [x] Automated behavioral tests and GitHub Actions.

## Phase 1 — Developer experience

- [x] Shared external command builder with positional indices and named flags.
- [x] POSIX quoting, explicit Windows shell-character restrictions.
- [x] Verbosity levels, exact commands, exit status, and errors in the TeX log.
- [x] Starred rendering to the log and optional debug snapshots.
- [ ] Windows end-to-end testing and broader Windows shell-character support.

## Phase 2 — Templates and data

- [x] Verbatim inline templates and inline expressions.
- [x] Verbatim inline YAML with named/default sources.
- [x] Additive aliases, namespaced `data.*`, ordered YAML/JSON root merging.
- [x] Configurable template search paths.
- [x] Content-based caching, distinct path identities, and functional no-cache.
- [ ] Richer inline data formats and stdin sources if demanded by use cases.

## Phase 3 — Native Lua backend

- [x] Native LuaLaTeX rendering without shell escape.
- [x] Single-file and merged YAML/JSON data, cached parsed templates.
- [x] Error paths/lines and Lua traceback reporting.
- [x] Whitespace control, conditionals, loops, common filters, and date formatting.
- [ ] Broader Liquid compatibility beyond the documented subset.

## Phase 4 — LaTeX integration

- [x] Templated sections with first-line title, body, and optional TOC title.
- [x] Array row rendering for lists/tables with explicit structure validation.
- [x] Auxiliary output digests and rerun warnings.
- [x] Recorder dependencies and latexmk handling for data-only input changes.
- [ ] Dedicated template modules and more specialized document helpers.

## Phase 5 — Toolkit

- [x] Pure custom native Lua filters.
- [x] Template validation without inserting output.
- [x] Opt-in request/cache-hit/CPU statistics and debug artifacts.
- [ ] Includes/partials and inheritance, with dependency tracking.
- [ ] Advanced profiling/dependency graphs.
- [ ] TikZ and bibliography integrations when requirements are established.

## Phase 6 — Workflow

- [x] Optional render/validate/inspect CLI using the shared runtime.
- [x] Declarative YAML/JSON multi-output pipelines with selective invalidation.
- [x] Small CV pipeline example.
- [ ] Larger CV/report teaching examples and dataset management.
- [ ] Project configuration conventions and HTML/export workflows.
