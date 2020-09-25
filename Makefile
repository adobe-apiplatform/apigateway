DOCKER_TAG ?= snapshot-`date +'%Y%m%d-%H%M'`
DOCKER_REGISTRY ?= 'docker.io'

docker:
	docker build -t adobeapiplatform/apigateway .

docker-debian:
	docker build -t adobeapiplatform/apigateway-debian:1.17.8.2 -f Dockerfile-debian .

.PHONY: docker-ssh
docker-ssh:
	docker run -ti --entrypoint='bash' adobeapiplatform/apigateway:latest

.PHONY: docker-run
docker-run:
	docker run --rm --name="apigateway" -p 80:80 -p 5000:5000 -p 9113:9113 adobeapiplatform/apigateway:latest ${DOCKER_ARGS}

docker-run-debian:
	docker run --rm --name="apigateway" -p 80:80 -p 5000:5000 -p 9113:9113 \
	    -e MARATHON_HOST=foo \
	    -e REMOTE_CONFIG_SYNC_INTERVAL=10s \
	    -e "REMOTE_CONFIG_SYNC_CMD=rclone sync --filter '- *resolvers.conf' --filter '- *environment.conf.d/api-gateway-env.server.conf' --filter '- *environment.conf.d/*vars.server.conf' --filter '- *environment.conf.d/*upstreams.http.conf' --exclude '*generated-conf.d/wsk**' azureblob:runtime-blob-apigw-config/api-gateway-config-0.1.36/ /etc/api-gateway/ ; rclone sync --exclude '**openwhisk_generated_apis.conf' azureblob:runtime-blob-apigw-apimgmt/ /etc/api-gateway/generated-conf.d/" \
	    -e RCLONE_CONFIG_AZUREBLOB_TYPE=azureblob \
	    -e RCLONE_CONFIG_AZUREBLOB_ACCOUNT=adobeioruntimestage \
	    -e RCLONE_CONFIG_AZUREBLOB_KEY=xUxNZSH7oVaMxqVVTvqdh8bvGx8McqAyUXXa4wu1tcZuagwSshboCawtCUo5IprPOt5s7Wd/QPE+b4nhUeU8+A== \
	    -e RCLONE_CONFIG_AZUREBLOB_ENDPOINT= \
	    adobeapiplatform/apigateway-debian:1.17.8.2 ${DOCKER_ARGS}

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
	docker tag adobeapiplatform/apigateway $(DOCKER_REGISTRY)/adobeapiplatform/apigateway:$(DOCKER_TAG)
	docker push $(DOCKER_REGISTRY)/adobeapiplatform/apigateway:$(DOCKER_TAG)

