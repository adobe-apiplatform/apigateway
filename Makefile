DOCKER_TAG ?= snapshot-`date +'%Y%m%d-%H%M'`
DOCKER_REGISTRY ?= ''

docker:
	docker build -t apiplatform/apigateway .

.PHONY: docker-ssh
docker-ssh:
	docker run -ti --entrypoint='bash' apiplatform/apigateway:latest

.PHONY: docker-run
docker-run:
	docker run --rm --name="apigateway" -p 8080:80 -p 8001:6001 apiplatform/apigateway:latest ${DOCKER_ARGS}

.PHONY: docker-attach
docker-attach:
	docker exec -i -t apigateway bash

.PHONY: docker-stop
docker-stop:
	docker stop apigateway
	docker rm apigateway

