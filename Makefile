IMAGE_NAME    = max
IMAGE_TAG     = stagex
IMAGE_FAT_TAG = stagex-fat

.PHONY: build build-fat extract extract-fat shell-debug clean

build:
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) --target package -f Containerfile .

build-fat:
	podman build -t $(IMAGE_NAME):$(IMAGE_FAT_TAG) --target package-fat -f Containerfile .

extract:
	@if ! podman image exists $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null; then \
		$(MAKE) build; \
	fi
	podman create --name max-extract $(IMAGE_NAME):$(IMAGE_TAG)
	podman cp max-extract:/usr/bin/max .
	podman cp max-extract:/usr/bin/maxcode .
	podman rm max-extract
	ls -lh max maxcode

extract-fat:
	@if ! podman image exists $(IMAGE_NAME):$(IMAGE_FAT_TAG) 2>/dev/null; then \
		$(MAKE) build-fat; \
	fi
	podman create --name max-fat-extract $(IMAGE_NAME):$(IMAGE_FAT_TAG)
	podman cp max-fat-extract:/usr/bin/max .
	podman cp max-fat-extract:/usr/bin/maxcode .
	podman rm max-fat-extract
	mv max max-fat
	ls -lh max-fat

shell-debug:
	podman run --rm -it \
		--entrypoint /bin/sh \
		docker.io/stagex/pallet-rust@sha256:abe9b95c93a5afa271f69fcd5eb18c8cd405fe5df6491a63c9418e3a170573dc

clean:
	-podman rmi $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):$(IMAGE_FAT_TAG) 2>/dev/null
	rm -f max maxcode max-fat
