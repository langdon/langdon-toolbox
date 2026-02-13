IMAGE_NAME := langdon-toolbox
CONTAINER_FNAME := Containerfile

help:
	@echo "make podman-build - Build and locally tag a new image using podman"
	@echo "make podman-build-force - Use a no-cache build using podman"
#	@echo "make podman-run - Launch the bot in the container using podman"

podman-build:
	@podman build -t $(IMAGE_NAME) --file=$(CONTAINER_FNAME) .
	@podman tag $(IMAGE_NAME) quay.io/langdon/langdon-toolbox:latest

podman-build-force:
	@podman pull fedora-toolbox:latest
	@podman build -t $(IMAGE_NAME) --file=$(CONTAINER_FNAME) --no-cache .
	@podman tag $(IMAGE_NAME) quay.io/langdon/langdon-toolbox:latest

#podman-run:
#	@podman run -it \
#		-p 3000:3000 \
#		-v ${PWD}:/app:z \
#		$(IMAGE_NAME)

