# liquidtex — project status and working notes

Updated **2026-11-05** on `fix/reproducible-rendering`, branched from local `dev`
commit `49a6ce4c1715370440e96de4b0188bb7baa0daed`. This supersedes the initial audit.
Changes on this branch are implemented and locally verified, pending review/merge.
GitHub issues should retain that distinction until the fixes reach the relevant
integration/default branch.

## Current state

The package now loads and renders under native LuaLaTeX without shell escape and
under the external backend with shell escape, including pdfLaTeX. Runtime sources
and example fixtures are included in the branch. The external backend has a
bundled renderer; a separately installed `template_parser` is no longer necessary.

All fourteen previously open issues (#11–#24) now have implementations, associated
behavioral coverage, and documentation. The previously closed-but-incomplete
features from #2–#6 and #10 have also been implemented. Windows end-to-end testing
and full Liquid compatibility remain outside the verified baseline.

## Code map

| Source | Responsibility |
| --- | --- |
| [liquidtex.dtx](liquidtex.dtx) | Canonical main package, options/API, inline capture, backend dispatch, logging, diagnostics, auxiliary digest markers; generated README/changelog/release metadata. |
| [utils/lqt-data.dtx](utils/lqt-data.dtx) | Additive source aliases and default/per-call source selection. |
| [utils/lqt-files.dtx](utils/lqt-files.dtx) | Ordered template lookup, JSON request serialization, dependency recording and log forwarding. |
| [utils/lqt-engine-external.dtx](utils/lqt-engine-external.dtx) | Runtime discovery and native/external bridge invocation with shell quoting. |
| [utils/lqt-messages.dtx](utils/lqt-messages.dtx) | Existing message definitions. Informational logging now goes through the main logging helper. |
| [scripts/liquid_engine.lua](scripts/liquid_engine.lua) | Liquid subset, parsed-template reuse, filters, data decoding, syntax checks and source-location/traceback errors. |
| [scripts/lqt_runtime.lua](scripts/lqt_runtime.lua) | Shared merge rules, content signatures, cache, external command builder/status handling, debug snapshots, row/section rendering and result protocol. |
| [scripts/lqt_bridge.lua](scripts/lqt_bridge.lua) | Internal `texlua` request bridge for the external backend. |
| [scripts/liquidtex.lua](scripts/liquidtex.lua) | Optional render/validate/inspect/pipeline CLI. |
| [scripts/json.lua](scripts/json.lua), [scripts/yaml.lua](scripts/yaml.lua) | Vendored decoders; array identity is preserved, including empty arrays. |
| [scripts/distribute.py](scripts/distribute.py), [Makefile](Makefile) | Extraction, actual user-manual build, complete TeX-tree staging and source/runtime/documentation ZIP archives. |
| [tests/run.py](tests/run.py) | Behavioral tests in disposable trees, including out-of-checkout runtime lookup. |
| [docs/corps/runtime.tex](docs/corps/runtime.tex) | Current API, supported subset, merge order, diagnostics, CLI/pipeline contracts and limitations. |
| [examples/pipeline.json](examples/pipeline.json) | Small two-output CV pipeline with tracked inputs. |

Edit `.dtx` sources rather than generated `.sty` files. README and CHANGELOG are
also generated from blocks in `liquidtex.dtx`. Extract with `make extract`.

## Completed fixes

- [x] Remove undefined LaTeX3 calls, unconditional Lua initialization, path debug
  output, and the exploratory public commands/sample module.
- [x] Track engine/parser/fixtures; narrow ignore rules so runtime work is visible.
- [x] Share a runtime between native and external modes; resolve installed Lua
  files through kpathsea rather than assuming the current directory is the repo.
- [x] Honor no-cache for every request; include cached content exactly once.
- [x] Key caches by document/input paths/action/configuration; invalidate by input
  contents, bundled sources and pure filter implementations rather than timestamps.
- [x] Support auxiliary output directories and remove shell-based file operations
  from native rendering/inline capture. The default cache is `liquidtex-cache`.
- [x] Use a single external command builder; honor positional index permutations,
  named flags and extra fixed arguments; quote POSIX paths including apostrophes.
- [x] Check actual renderer exit status, forward error text, and publish output
  only after success. Output written before a failing exit is not typeset.
- [x] Preserve default data when adding aliases; implement `data.NAME` namespaces
  and deterministic YAML/JSON merging. Replace arrays, including empty arrays.
- [x] Capture template/data environments verbatim, preserving Liquid percent tags;
  support both named and default inline YAML blocks.
- [x] Fix whitespace-control tags/expressions, underscored filters with arguments,
  literal replacement, missing-data errors, and unknown-filter handling.
- [x] Add starred logging, debug artifacts, verbosity levels, template validation,
  statistics, native custom filters, sections/TOC, and array row templates.
- [x] Record inputs for `latexmk`; write output digests into `.aux` and warn on
  output changes. Verify data-only changes trigger recompilation.
- [x] Add CLI render/validate/inspect and declarative multi-output pipelines with
  selective invalidation and content-preserving destination writes.
- [x] Build the separate user manual; repair install/archive contents; unify
  metadata/changelog at **0.3.0 / 2026-11-05**; add tests and CI configuration.

## GitHub issue mapping

The GitHub states below describe the starting point. The branch implements these
items; open issues are moved to review status with implementation/test evidence,
not silently treated as changes already merged into `dev` or `main`.

| Issue | Starting state | Implementation / evidence |
| --- | --- | --- |
| [#1](https://github.com/olirwin/liquidtex/issues/1) Foundation | Closed | Loading restored, experiments removed, source/distribution cleanup. |
| [#2](https://github.com/olirwin/liquidtex/issues/2) Command builder | Closed | Positional permutations, named flags, extra arguments, POSIX quote regression; Windows restrictions documented. |
| [#3](https://github.com/olirwin/liquidtex/issues/3) Logger | Closed | Shared informational helper; off/basic/full/trace configuration. |
| [#4](https://github.com/olirwin/liquidtex/issues/4) External errors | Closed | Integration test verifies exit 7 and stderr after an engine writes output. |
| [#5](https://github.com/olirwin/liquidtex/issues/5) Starred input | Closed | Logs rendered code and does not insert it into PDF output. |
| [#6](https://github.com/olirwin/liquidtex/issues/6) Debug directory | Closed | Input/data/output/log snapshots; existing directory reuse. |
| [#7](https://github.com/olirwin/liquidtex/issues/7) Inline templates | Closed | Verbatim environment with actual conditional/loop tags tested. |
| [#8](https://github.com/olirwin/liquidtex/issues/8) Inline expressions | Closed | Inline rendering tested; normal TeX parsing/moving-argument limits documented. |
| [#9](https://github.com/olirwin/liquidtex/issues/9) Inline data | Closed | Named and alias-free default YAML environments tested. |
| [#10](https://github.com/olirwin/liquidtex/issues/10) Namespaced sources | Closed | Literal `data.*` keys, deterministic merging and selected-data override implemented. |
| [#11](https://github.com/olirwin/liquidtex/issues/11) Template paths | Open | First matching configured directory wins; direct-path precedence and relative/absolute rules documented. |
| [#12](https://github.com/olirwin/liquidtex/issues/12) Lua backend | Open | Native no-shell-escape integration, external/pdfLaTeX parity and installed-package checks. |
| [#13](https://github.com/olirwin/liquidtex/issues/13) Lua merging | Open | JSON/YAML root merge, namespaces and local override regression. |
| [#14](https://github.com/olirwin/liquidtex/issues/14) Tracebacks | Open | Invalid templates/filters report template path, line information and Lua traceback. |
| [#15](https://github.com/olirwin/liquidtex/issues/15) Sections | Open | First-line title plus body; explicit short TOC title tested over two runs. |
| [#16](https://github.com/olirwin/liquidtex/issues/16) Lists/tables | Open | Ordered `item`/`forloop` row context; array-path selection; invalid structures and empty arrays tested. |
| [#17](https://github.com/olirwin/liquidtex/issues/17) Reruns | Open | Auxiliary digest warnings and real `latexmk` data-only change test. |
| [#18](https://github.com/olirwin/liquidtex/issues/18) Custom filters | Open | Native `\liquidfilter{name}{function...}` with tested row rendering and documented purity limits. |
| [#19](https://github.com/olirwin/liquidtex/issues/19) Validation | Open | TeX command and CLI, no inserted output; malformed tags/filter expressions rejected. |
| [#20](https://github.com/olirwin/liquidtex/issues/20) Diagnostics | Open | Opt-in request/cache-hit/CPU counters; known hit counts asserted. |
| [#21](https://github.com/olirwin/liquidtex/issues/21) CLI | Open | Render, validate and inspect commands tested with the shared runtime. |
| [#22](https://github.com/olirwin/liquidtex/issues/22) Pipelines | Open | YAML/JSON format documented; two-output cache and selective invalidation tested. |
| [#23](https://github.com/olirwin/liquidtex/issues/23) Documentation | Open | Updated README/manual/examples; real manual PDF built through repaired Makefile. |
| [#24](https://github.com/olirwin/liquidtex/issues/24) No-cache | Open | Both backends rerender repeated calls with zero cache hits. |
| [#25](https://github.com/olirwin/liquidtex/issues/25) Refactor | Closed / duplicate | Remains a duplicate of #26. |
| [#26](https://github.com/olirwin/liquidtex/issues/26) Modules | Closed | Four TeX helper sources retained; Lua runtime responsibilities separated. |

## Verification

Environment: TeX Live 2026 / LuaHBTeX 1.24.0, LaTeX2e 2025-11-01,
LaTeX3 2026-01-19, Python 3. Tests generate their own files under `/tmp`.

- `make extract`: succeeds and generates all main/helper runtime packages.
- `python3 tests/run.py`: **15 behavioral integration tests pass**. These include
  native/external/pdfLaTeX output, warm caches, same-timestamp content changes,
  no-cache, inline capture, aliases/merging, search order, collisions, quoted
  external arguments/failures, validation, filters, empty arrays, TOC, auxiliary
  output directories, `latexmk` dependencies and CLI/pipeline invalidation. Both complete repository examples are also covered.
- `make doc`: succeeds; the actual user manual is **18 pages**, with some existing
  typography/glossary/hyperlink warnings. No unresolved-reference build failure.
- Staged TeX-tree install compiled a new native document from an unrelated
  directory using only the installed runtime/helpers.
- ZIP content assertions cover main/helper packages, engine/parser, manual source
  and PDF, plus runnable example inputs.
- GitHub Actions configuration runs extraction/tests on Ubuntu; hosted execution
  is checked after publishing the branch. A CI result must not be inferred from
  the local suite alone.

## Remaining work and limits

- [ ] Verify Windows end to end. Current shell quoting supports ordinary paths
  with spaces but explicitly rejects Windows shell metacharacters. Add a Windows
  test matrix before claiming broad Windows compatibility.
- [ ] Broaden the documented Liquid subset: includes/partials, inheritance,
  assignments, loop modifiers and complete expression compatibility. Includes
  must also participate in dependency tracking when added.
- [ ] Improve manual typography and optional concept/glossary/index generation.
- [ ] Add larger CV/report/teaching examples, profiling/dependency graphs and the
  later framework/export features in [ROADMAP.md](ROADMAP.md).
- [ ] Native output paths must satisfy TeX's output restrictions. Hidden or
  absolute output directories may be refused; use allowed relative paths.
- [ ] Custom filters are native-only and should be pure. Unknown external state
  and filter upvalues are not tracked; use no-cache for those cases.

When updating this file, record actual checks and the branch/merge state. Keep
GitHub issue closure distinct from fixes that are only present on a feature branch.
