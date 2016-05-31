DOCKER_TAG ?= snapshot-`date +'%Y%m%d-%H%M'`
DOCKER_REGISTRY ?= ''

docker:
	docker build -t adobeapiplatform/apigateway .

.PHONY: docker-ssh
docker-ssh:
	docker run -ti --entrypoint='bash' adobeapiplatform/apigateway:latest

.PHONY: docker-run
docker-run:
	docker run --rm --name="apigateway" -p 80:80 -p 5000:5000 adobeapiplatform/apigateway:latest ${DOCKER_ARGS}

.PHONY: docker-debug
docker-debug:
	#Volumes directories must be under your Users directory
	mkdir -p ${HOME}/tmp/apiplatform/apigateway
	rm -rf ${HOME}/tmp/apiplatform/apigateway/api-gateway-config
	cp -r `pwd`/api-gateway-config ${HOME}/tmp/apiplatform/apigateway/
	docker run --name="apigateway" \
			-p 80:80 -p 5000:5000 \
			-e "LOG_LEVEL=info" -e "DEBUG=true" \
			-v ${HOME}/tmp/apiplatform/apigateway/api-gateway-config/:/etc/api-gateway \
			adobeapiplatform/apigateway:latest ${DOCKER_ARGS}

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
	docker tag -f adobeapiplatform/apigateway $(DOCKER_REGISTRY)/adobeapiplatform/apigateway:$(DOCKER_TAG)
	docker push $(DOCKER_REGISTRY)/adobeapiplatform/apigateway:$(DOCKER_TAG)

