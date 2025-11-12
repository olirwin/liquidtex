| liquidtex: | LaTeX with integrated Liquid templating                        |
|------------|----------------------------------------------------------------|
| Author:    | Oliver Irwin                                                   |
| E-mail:    | oliver@irwin.sh                                                |
| License:   | Released under the LaTeX Project Public License v1.3c or later |
| See:       | http://www.latex-project.org/lppl.txt                          |

Running `make` generates the derived files README, liquidtex.pdf and liquidtex.sty.
Running `make inst` installs the files in the user's TeX tree.
Running `make install` installs the files in the local TeX tree.

# liquidtex

`liquidtex` is a LaTeX package that integrates **Liquid templates**
directly into the LaTeX compilation process. It allows you to write LaTeX
documents that include dynamic placeholders and conditional logic, rendered
automatically from structured data sources (e.g. YAML, JSON) at compile
time.

## Features

- Seamless integration of **Liquid templating** within LaTeX documents.
- Support for **YAML** and **JSON** data sources.
- Verbose **logging** and **error reporting** for debugging template
  rendering.
- Configurable **options** for data source paths, compilation behaviour,
  and output verbosity.
- Compatible with `.sty` or `.dtx` distribution formats.

## Use Cases

- Auto-generated CVs or reports based on structured data.
- Dynamic lecture notes, syllabi, or publication lists.
- Research documents where repetitive elements are driven by metadata.
\NewDocumentCommand{\hello}{ O{World} }{Hello, #1!}
