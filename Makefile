DOCKER ?= docker
PROJ_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST)))).
REGISTRY ?= jarrednicholls/cross-rust
RUST_VERSION ?= 1.49.0

default: all

all: docker

docker:
	$(DOCKER) build \
		-t $(REGISTRY):$(RUST_VERSION) \
		-t $(REGISTRY):latest \
		--build-arg RUST_VERSION=$(RUST_VERSION) \
		-f $(PROJ_DIR)/Dockerfile \
		$(PROJ_DIR)/checksums

push:
	$(DOCKER) push $(REGISTRY):$(RUST_VERSION) && $(DOCKER) push $(REGISTRY):latest
