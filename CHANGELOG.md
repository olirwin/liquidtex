# Changelog

## 0.3.0 ^^e2^^80^^94 2026-11-05

- Restore package loading and isolate the native Lua backend from pdfLaTeX.
- Ship runtime libraries and reproducible example data/templates.
- Share a content-based cache/runtime between native and external rendering;
  honor no-cache, detect input/configuration changes, avoid basename collisions,
  and include cached output once.
- Support quoted positional/named external commands with exit-status checks and
  stderr in the LaTeX log; supply a bundled external renderer and companion CLI.
- Add template paths, additive aliases, ordered YAML/JSON merging and namespaces.
- Preserve verbatim inline templates/data; support default inline YAML blocks.
- Add debug snapshots, starred logging, verbosity levels, validation, statistics,
  custom native filters, section/TOC helpers, and array row rendering.
- Add auxiliary output-directory support, dependency recording, output rerun
  markers, and cached CLI multi-output pipelines.
- Fix whitespace control, underscored filters, literal replacement, and Lua errors.
- Repair manual/build/install/archive recipes; add integration tests and CI.

## 0.2.0 ^^e2^^80^^94 2025-11-21

- Inline template blocks/expressions, named sources, and inline YAML data.

## 0.1.0 ^^e2^^80^^94 2025-11-13

- Initial external-engine integration, configuration, caching, and documentation.
