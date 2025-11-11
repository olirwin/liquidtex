-----------------------------------------------------------------------

- `liquidtex` --- LaTeX with integrated Liquid, version 0.0.1
- E-mail: `oliver@irwin.sh`
- Released under the LaTeX Project Public License v1.3c or later. See
  http://www.latex-project.org/lppl.txt

-----------------------------------------------------------------------

**The `liquidtex` bundle provides a LaTeX package file to help writing
LaTeX files with integrated Liquid templates.**

The package is supplied in `.dtx` format. If you want to unpack the `.dtx`
yourself, running:

    pdftex liquidtex.dtx

will extract the package whereas:

    pdflatex liquidtex.dtx

will extract it and also typeset the documentation of the code.

Typesetting the documentation of the package requires:

- a number of packages in addition to those needed to use the `liquidtex`
   classes.  To compile the documentation without error, you will need, among
   others, the `denisbdoc` package for documentation.
