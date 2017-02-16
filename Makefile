TAG ?= latest
IMAGE_NAME ?= s2i-openresty-centos7:$(TAG)
FORCE_PULL ?= --pull
REGISTRY ?= quay.io/3scale

build: ## Build builder image
	docker build $(FORCE_PULL) --tag $(IMAGE_NAME) .

build-runtime: ## Build runtime image
	docker build $(FORCE_PULL) --tag $(IMAGE_NAME)-runtime -f Dockerfile.runtime .

.PHONY: test test/test-app

test/test-app:
	git submodule update --init --recursive $@
	rm "$@/.git"
	ln -sfv ../../.git/modules/$@ "$@/.git"
bash: ## Run bash in built builder image
	docker run -it --user root $(IMAGE_NAME) bash

push: ## Tag and push the builder image to the docker registry
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME)
	docker push $(REGISTRY)/$(IMAGE_NAME)

push-runtime: ## Tag and push the runtime iamge to the docker registry
	docker tag $(IMAGE_NAME)-runtime $(REGISTRY)/$(IMAGE_NAME)-runtime
	docker push $(REGISTRY)/$(IMAGE_NAME)-runtime

test: ## Run tests
test: test-build test/test-app
	test/run

test-build: ## Test just building the images
test-build: export IMAGE_NAME := $(IMAGE_NAME)-candidate
test-build: build build-runtime

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
