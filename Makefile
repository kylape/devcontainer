.PHONY: build-image
build-image:
	podman build . | tee /tmp/devcontainer-image-tag

.PHONY: push-image
push-image: build-image
	podman tag $(shell tail -n 1 /tmp/devcontainer-image-tag) quay.io/klape/devcontainer:latest
	podman push --tls-verify=false quay.io/klape/devcontainer:latest

.PHONY: push-image-local
push-image-local: build-image
	podman tag $(shell tail -n 1 /tmp/devcontainer-image-tag) localhost:5001/devcontainer/devcontainer:latest
	podman push --tls-verify=false localhost:5001/devcontainer/devcontainer:latest

.PHONY: push-image-local
build-push-redeploy: push-image-local
	kubectl delete pod -l app=devcontainer
