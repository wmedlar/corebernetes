DOCKER_RUN_OPTS := -it -v "$(CURDIR):/etc/corebernetes:ro" -w /etc/corebernetes --rm

.PHONY: lint
lint: lint-markdown

.PHONY: lint-markdown
ifneq ($(CI),true)
lint-markdown: PREFIX ?= docker run $(DOCKER_RUN_OPTS) node:alpine
endif
lint-markdown:
	$(PREFIX) npm run lint:markdown
