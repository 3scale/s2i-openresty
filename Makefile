IMAGE_NAME ?= s2i-openresty-centos7
FORCE_PULL ?= --pull
REGISTRY ?= quay.io/3scale

build:
	docker build $(FORCE_PULL) --tag $(IMAGE_NAME) .

.PHONY: test test/test-app

test/test-app:
	git submodule update --init --recursive $@

bash:
	docker run -it --user root $(IMAGE_NAME) bash

push:
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME)
	docker push $(REGISTRY)/$(IMAGE_NAME)

test: export IMAGE_NAME := $(IMAGE_NAME)-candidate
test: build test/test-app
	test/run
