INFRA ?= ../brandymint/infra
STAGE ?= goga-infra
APP ?= no_fluff
DOMAIN ?= no-fluff.brandymint.ru
REGISTRY ?= registry.brandymint.ru
IMAGE := $(REGISTRY)/dapi/no_fluff
TAG ?= $(shell git rev-parse HEAD)
OCI_ARCHIVE := tmp/no-fluff-$(TAG).oci.tar

.PHONY: help provision test up down image-build image-push deploy-diff infra-deploy webhook-set webhook-delete webhook-info verify deploy

help:
	@echo "No Fluff"
	@echo ""
	@echo "Local:"
	@echo "  make provision"
	@echo "  make test"
	@echo "  make up"
	@echo "  make down"
	@echo ""
	@echo "Production (goga-office):"
	@echo "  make image-build"
	@echo "  make image-push"
	@echo "  make deploy-diff"
	@echo "  make deploy"
	@echo "  make verify"
	@echo "  make webhook-info"

provision:
	mise exec -- dip provision

test:
	mise exec -- dip test

up:
	mise exec -- dip rails s

down:
	mise exec -- dip down

image-build:
	@mkdir -p tmp
	@rm -f $(OCI_ARCHIVE)
	docker buildx build \
		--platform linux/amd64 \
		--output type=oci,dest=$(OCI_ARCHIVE) \
		-t $(IMAGE):$(TAG) .
	@echo "Built $(OCI_ARCHIVE)"

image-push: image-build
	direnv exec $(INFRA) $(INFRA)/scripts/publish-oci-to-goga-registry.sh \
		$(OCI_ARCHIVE) $(IMAGE):$(TAG)

deploy-diff:
	direnv exec $(INFRA) $(MAKE) -C $(INFRA) app-diff STAGE=$(STAGE) APP=$(APP)

infra-deploy:
	direnv exec $(INFRA) $(MAKE) -C $(INFRA) app-update STAGE=$(STAGE) APP=$(APP) TAG=$(TAG)

webhook-set:
	INFRA=$(INFRA) DOMAIN=$(DOMAIN) uv run --with 'httpx[socks]' python bin/telegram-webhook set

webhook-delete:
	INFRA=$(INFRA) DOMAIN=$(DOMAIN) uv run --with 'httpx[socks]' python bin/telegram-webhook delete

webhook-info:
	INFRA=$(INFRA) DOMAIN=$(DOMAIN) uv run --with 'httpx[socks]' python bin/telegram-webhook info

verify:
	direnv exec $(INFRA) kubectl --context=goga-office -n no-fluff-production \
		wait --for=condition=Ready pod -l app.kubernetes.io/instance=no-fluff --timeout=180s
	curl --fail --show-error --silent https://$(DOMAIN)/up >/dev/null
	curl --fail --show-error --silent https://$(DOMAIN)/ >/dev/null
	curl --fail --show-error --silent https://$(DOMAIN)/icon.svg >/dev/null
	curl --fail --show-error --silent https://$(DOMAIN)/site.webmanifest >/dev/null
	curl --fail --show-error --silent https://$(DOMAIN)/og-image.png >/dev/null

deploy: image-push webhook-delete infra-deploy verify
