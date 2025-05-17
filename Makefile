#-*- mode: makefile; -*-

SHELL := /bin/bash
.SHELLFLAGS := -ec

MODULE_NAME := DarkPAN::Utils
MODULE_PATH := $(subst ::,/,$(MODULE_NAME)).pm

PERL_MODULES = \
    lib/$(MODULE_PATH) \
    lib/DarkPAN/Utils.pm \
    lib/DarkPAN/Utils/Docs.pm

VERSION := $(shell perl -I lib -M$(MODULE_NAME) -e 'print $$$(MODULE_NAME)::VERSION;')

TARBALL = $(subst ::,-,$(MODULE_NAME))-$(VERSION).tar.gz

$(TARBALL): buildspec.yml $(PERL_MODULES) requires test-requires README.md
	make-cpan-dist.pl -b $<

README.md: lib/$(MODULE_PATH)
	pod2markdown $< > $@

all: $(TARBALL)

clean:
	rm -f *.tar.gz
