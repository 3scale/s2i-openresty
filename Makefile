IMAGE_NAME ?= s2i-openresty-centos7
build:
	docker build --pull --tag $(IMAGE_NAME) .

.PHONY: test test/test-app

test/test-app:
	git submodule update --init --recursive $@

test: export IMAGE_NAME := $(IMAGE_NAME)-candidate
test: build test/test-app
	test/run
