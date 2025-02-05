DOCKER_TAG ?= snapshot-`date +'%Y%m%d-%H%M'`
DOCKER_REGISTRY ?= 'docker.io'
BASE_REGISTRY ?= 'docker.io'
IMAGE_NAME ?= 'adobeapiplatform/apigateway'
CONFIG_SUPERVISOR_VERSION ?= '1.0.3'

docker:
	docker build --build-arg BASE_REGISTRY=${BASE_REGISTRY} --build-arg CONFIG_SUPERVISOR_VERSION=${CONFIG_SUPERVISOR_VERSION} -t ${IMAGE_NAME} .

docker-debian:
	docker build --build-arg BASE_REGISTRY=${BASE_REGISTRY} --build-arg CONFIG_SUPERVISOR_VERSION=${CONFIG_SUPERVISOR_VERSION} -t ${IMAGE_NAME}:10-debian-1.21.4.2 -f Dockerfile-debian .

docker-debian-multiarch-push:
	docker buildx build --platform linux/amd64,linux/arm64 --build-arg BASE_REGISTRY=${BASE_REGISTRY} --build-arg CONFIG_SUPERVISOR_VERSION=${CONFIG_SUPERVISOR_VERSION} --push -t $(DOCKER_REGISTRY)/${IMAGE_NAME}:$(DOCKER_TAG) -f Dockerfile-debian .

.PHONY: docker-ssh
docker-ssh:
	docker run -ti --entrypoint='bash' ${IMAGE_NAME}:latest

.PHONY: docker-run
docker-run:
	docker run --rm --name="apigateway" -p 80:80 -p 5000:5000 -p 9113:9113 ${IMAGE_NAME}:latest ${DOCKER_ARGS}

.PHONY: docker-debug
docker-debug:
	#Volumes directories must be under your Users directory
	mkdir -p ${HOME}/tmp/apiplatform/apigateway
	rm -rf ${HOME}/tmp/apiplatform/apigateway/api-gateway-config
	cp -r `pwd`/api-gateway-config ${HOME}/tmp/apiplatform/apigateway/
	docker run --name="apigateway" \
			-p 80:80 -p 5000:5000 -p 9113:9113 \
			-e "LOG_LEVEL=info" -e "DEBUG=true" \
			-v ${HOME}/tmp/apiplatform/apigateway/api-gateway-config/:/etc/api-gateway \
			${IMAGE_NAME}:latest ${DOCKER_ARGS}

.PHONY: docker-reload
docker-reload:
	cp -r `pwd`/api-gateway-config ${HOME}/tmp/apiplatform/apigateway/
	docker exec apigateway api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf
	docker exec apigateway api-gateway -s reload

.PHONY: docker-attach
docker-attach:
	docker exec -i -t apigateway bash

.PHONY: docker-stop
docker-stop:
	docker stop apigateway
	docker rm apigateway

.PHONY: docker-compose
docker-compose:
	#Volumes directories must be under your Users directory
	mkdir -p ${HOME}/tmp/apiplatform/apigateway
	rm -rf ${HOME}/tmp/apiplatform/apigateway/api-gateway-config
	cp -r `pwd`/api-gateway-config ${HOME}/tmp/apiplatform/apigateway/
	sed -i '' 's/127\.0\.0\.1/redis\.docker/' ${HOME}/tmp/apiplatform/apigateway/api-gateway-config/environment.conf.d/api-gateway-upstreams.http.conf
	# clone api-gateway-redis block
	sed -e '/api-gateway-redis/,/}/!d' ${HOME}/tmp/apiplatform/apigateway/api-gateway-config/environment.conf.d/api-gateway-upstreams.http.conf | sed 's/-redis/-redis-replica/' >> ${HOME}/tmp/apiplatform/apigateway/api-gateway-config/environment.conf.d/api-gateway-upstreams.http.conf
	docker-compose up

.PHONY: docker-push
docker-push:
	docker tag ${IMAGE_NAME} $(DOCKER_REGISTRY)/${IMAGE_NAME}:$(DOCKER_TAG)
	docker push $(DOCKER_REGISTRY)/${IMAGE_NAME}:$(DOCKER_TAG)

