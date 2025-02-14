PONYC ?= ponyc
config ?= debug
ifdef config
  ifeq (,$(filter $(config),debug release))
    $(error Unknown configuration "$(config)")
  endif
endif

ifeq ($(config),debug)
	PONYC_FLAGS += --debug
endif

PONYC_FLAGS += -o build/$(config)

ALL: pony-lsd

build/$(config)/pony-lsd: deps pony-lsd/*.pony pony-lsd/lsp/v3/*.pony | build/$(config)
	corral run -- $(PONYC) ${PONYC_FLAGS} pony-lsd

build/$(config)/test: .deps pony-lsd/*.pony pony-lsd/test/*.pony | build/$(config)
	corral run -- $(PONYC) ${PONYC_FLAGS} pony-lsd/test

build/$(config):
	mkdir -p build/$(config)

deps:
	corral fetch

pony-lsd: build/$(config)/pony-lsd

test: build/$(config)/test
	build/$(config)/test

clean:
	rm -rf build _corral _repos

.PHONY: clean test pony-lsd deps
