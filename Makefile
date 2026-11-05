NAME := liquidtex
VERSION := $(shell sed -n 's/.*\\def\\liquidtexversion{\([^}]*\)}.*/\1/p' liquidtex.dtx | head -1)
TEXMFHOME ?= $(shell kpsewhich --var-value TEXMFHOME)
TEXMFLOCAL ?= $(shell kpsewhich --var-value TEXMFLOCAL)
GENERATED := liquidtex.sty lqt-data.sty lqt-files.sty lqt-messages.sty lqt-engine-external.sty liquidtex.ins README.md CHANGELOG.md
DOCS := $(shell find docs -type f \( -name '*.tex' -o -name '*.sty' -o -name '.latexmkrc' \))

.PHONY: all extract doc test clean distclean inst install zip
all: extract liquidtex.pdf
extract: $(GENERATED)
$(GENERATED) &: liquidtex.dtx $(wildcard utils/*.dtx)
	tex -interaction=nonstopmode liquidtex.dtx

doc: liquidtex.pdf
liquidtex.pdf: $(DOCS) liquidtex.dtx
	latexmk -cd -lualatex -shell-escape -halt-on-error -interaction=nonstopmode docs/liquidtex.tex
	cp docs/liquidtex.pdf liquidtex.pdf

test:
	python3 tests/run.py

inst: all
	python3 scripts/distribute.py install "$(DESTDIR)$(TEXMFHOME)"
install: all
	python3 scripts/distribute.py install "$(DESTDIR)$(TEXMFLOCAL)"
zip: all
	python3 scripts/distribute.py zip "$(VERSION)"
clean:
	python3 scripts/distribute.py clean
distclean: clean
	python3 scripts/distribute.py distclean
