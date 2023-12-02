FIND ?= /usr/bin/find
CP   ?= /bin/cp

default: clean build

.PHONY: clean
clean:
	@rm -rf dist

.PHONY: build
build:
	jsonnet -J vendor -c -m dist monitoring.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	$(FIND) dist -type f ! -name '*.yaml' -delete
	$(FIND) dist -type f -name '*.yaml' -exec bash -c 'mv "$$1" "$${1%.yaml}".yml' - '{}' \;

