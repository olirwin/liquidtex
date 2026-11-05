NAME  = liquidtex
SHELL = zsh
PWD   = $(shell pwd)
VERS  = $(shell grep -E "\\\\version{[0-9.]*.*}" liquidtex.dtx | sed -E "s|\\\\version\\{([0-9.a-z]*).*\\}|\1|")
LOCAL := $(shell kpsewhich --var-value TEXMFLOCAL | awk -F: '{print $$2}')
UTREE = $(shell kpsewhich --var-value TEXMFHOME)
TEXCC = lualatex

$(warning $(LOCAL))

all:	$(NAME).pdf
	test -e README.md || exit 0
$(NAME).pdf: $(NAME).dtx
	$(TEXCC) -shell-escape -recorder -interaction=batchmode $(NAME).dtx >/dev/null
	if [ -f $(NAME).glo ]; then makeindex -q -s gglo.ist -o $(NAME).gls $(NAME).glo; fi
	if [ -f $(NAME).idx ]; then makeindex -q -s gind.ist -o $(NAME).ind $(NAME).idx; fi
	$(TEXCC) --recorder --interaction=nonstopmode $(NAME).dtx > /dev/null
	$(TEXCC) --recorder --interaction=nonstopmode $(NAME).dtx > /dev/null
clean:
	rm -f $(NAME).{aux,fls,glo,gls,hd,idx,ilg,ind,ins,log,out,bcf,glo2,run.xml,xdy,mw,synctex.gz,bbl,blg,atfi,fdb_latexmk}
distclean: clean
	rm -f $(NAME).{pdf,sty,drv,pkg} README.md lqt-*.sty
inst: all
	mkdir -p $(UTREE)/{tex,source,doc}/latex/$(NAME)
	cp $(NAME).dtx $(UTREE)/source/latex/$(NAME)
	cp $(NAME).sty $(UTREE)/tex/latex/$(NAME)
	cp $(NAME).pdf $(UTREE)/doc/latex/$(NAME)
	cp -r scripts $(UTREE)/tex/latex/$(NAME)
install: all
	sudo mkdir -p $(LOCAL)/{tex,source,doc}/latex/$(NAME)
	sudo cp $(NAME).dtx $(LOCAL)/source/latex/$(NAME)
	sudo cp $(NAME).sty $(LOCAL)/tex/latex/$(NAME)
	sudo cp $(NAME).pdf $(LOCAL)/doc/latex/$(NAME)
	sudo cp lqt-*.sty $(LOCAL)/tex/latex/$(NAME)
	sudo cp -r utils $(LOCAL)/source/latex/$(NAME)
	sudo cp -r scripts $(LOCAL)/tex/latex/$(NAME)
zip: all
	ln -sf . $(NAME)
	zip -Drq $(PWD)/$(NAME)-$(VERS).zip $(NAME)/{README.md,CHANGELOG.md,$(NAME).{pdf,dtx,pkg,drv},utils,scripts}
	zip -Drq $(PWD)/$(NAME).zip $(NAME)/{README.md,CHANGELOG.md,$(NAME).{pdf,dtx,pkg,drv},utils,scripts}
	rm $(NAME)
