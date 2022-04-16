OCAML_VERSION ?= 4.12.1

.PHONY: init
init:
	opam switch create . -y --no-install $(OCAML_VERSION)
	opam install . -y --deps-only
	opam install -y ocaml-lsp-server ocamlformat

.PHONY : build
build :
	@dune build -p dream-pure,dream-httpaf,dream --no-print-directory @install

.PHONY : watch
watch :
	@dune build -p dream-pure,dream-httpaf,dream --no-print-directory -w

TEST ?= test
ROOT := $(shell [ -f ../dune-workspace ] && echo .. || echo .)

.PHONY : test
test :
	@find $(ROOT) -name '*.coverage' | xargs rm -f
	@dune build --no-print-directory \
	  --instrument-with bisect_ppx --force @$(TEST)/runtest
	@bisect-ppx-report html --expect=./src/core
	@bisect-ppx-report summary
	@echo See _coverage/index.html

.PHONY : test-watch
test-watch :
	@dune build --no-print-directory -w @$(TEST)/runtest

.PHONY : coverage-serve
coverage-serve :
	cd _coverage && dune exec -- serve -p 8082

.PHONY : promote
promote :
	dune promote
	@make --no-print-directory test

.PHONY : docs
docs : 
	dune build @doc
	@rm -rf ./_doc
	@cp -r ./_build/default/_doc/_html/. ./_doc

.PHONY : docs-publish
docs-publish :
	git subtree push --prefix _doc origin gh-pages