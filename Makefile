DOCKER_TAG ?= snapshot-`date +'%Y%m%d-%H%M'`
DOCKER_REGISTRY ?= ''

docker:
	docker build -t apiplatform/apigateway .

.PHONY: docker-ssh
docker-ssh:
	docker run -ti --entrypoint='bash' apiplatform/apigateway:latest

.PHONY: docker-run
docker-run:
	docker run --rm --name="apigateway" -p 8080:80 apiplatform/apigateway:latest ${DOCKER_ARGS}

.PHONY: docker-debug
docker-debug:
	#Volumes directories must be under your Users directory
	mkdir -p ${HOME}/tmp/apiplatform/apigateway
	rm -rf ${HOME}/tmp/apiplatform/apigateway/api-gateway-config
	#ln -s  `pwd`/api-gateway-config ${HOME}/tmp/apiplatform/apigateway/api-gateway-config
	cp -r `pwd`/api-gateway-config ${HOME}/tmp/apiplatform/apigateway/
	docker run --name="apigateway" \
			-p 8080:80 \
			-e "LOG_LEVEL=debug" \
			-v ${HOME}/tmp/apiplatform/apigateway/api-gateway-config/:/etc/api-gateway \
			apiplatform/apigateway:latest ${DOCKER_ARGS}

.PHONY: docker-reload
docker-reload:
	docker exec apigateway api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf
	docker exec apigateway api-gateway -s reload

.PHONY: docker-attach
docker-attach:
	docker exec -i -t apigateway bash

.PHONY: docker-stop
docker-stop:
	docker stop apigateway
	docker rm apigateway

