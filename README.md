  apigateway
=============
A performant API Gateway based on Openresty and NGINX.

### Quick start

```
docker run --name="apigateway" \
            -p 80:80 \
            -e "MARATHON_HOST=http://<marathon_host>:<port>/" \
            -e "LOG_LEVEL=info" \
            adobeapiplatform/apigateway:latest
```

This command starts an API Gateway that automatically discovers the services running in Marathon.
The discovered services are exposed on individual VHosts as you can see in the [config file](https://github.com/adobe-apiplatform/apigateway/blob/master/api-gateway-config/conf.d/marathon_apis.conf#L36).

#### Accessing a Marathon app

For example, if you have an application named `hello-world` you can access it on its VHost in 2 ways:

 1. Edit `/etc/hosts` and add `<docker_host_ip> hello-world.api.localhost` then browse to `http://hello-world.api.localhost`
 2. Sending the Host header in a curl command: `curl -H "Host:hello-world.api.localhost" http://<docker_host_ip>`

The [discovery script](https://github.com/adobe-apiplatform/apigateway/blob/master/api-gateway-config/marathon-service-discovery.sh) is provided as an example for a quick-start and it can be replaced with your favourite discovery mechanism.
The script updates a [configuration file](https://github.com/adobe-apiplatform/apigateway/blob/master/api-gateway-config/environment.conf.d/api-gateway-upstreams.http.conf) containing all the NGINX upstreams that are used in the [config file](https://github.com/adobe-apiplatform/apigateway/blob/master/api-gateway-config/conf.d/marathon_apis.conf#L36).

#### Resolvers
While starting up this container automatically creates the `/etc/api-gateway/conf.d/includes/resolvers.conf` config file using `/etc/resolv.conf` as the source.
To learn more about the `resolver` directive in NGINX see the [docs](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver).

#### Running the API Gateway outside of Marathon and Mesos
Besides the discovery part which is dependent on Marathon at the  moment, the API Gateway can run on its own as well. The Marathon service discovery is activated with the ` -e "MARATHON_HOST=http://<marathon_host>:<port>/"`.

### Developer guide

 To build the docker image locally use:
 ```
  make docker
 ```

 To SSH into the newly built image use ( note that this is not the running image):
 ```
  make docker-ssh
 ```

#### Running and Stopping the Docker image
 ```
  make docker-run
 ```
 The main API Gateway process is exposed to port `80`. To test that the Gateway works see its `health-check`:
 ```
  $ curl http://<docker_host_ip>/health-check
    API-Platform is running!
 ```
 If you're up for a quick performance test, you can play with Apache Benchmark via Docker:

 ```
  docker run jordi/ab ab -k -n 200000 -c 500 http://<docker_host_ip>/health-check
 ```

 To run docker mounting the local `api-gateway-config` directory into `/etc/api-gateway/` issue:

 ```bash
 $ make docker-debug
 ```
 In debug mode the docker container starts a special `api-gateway` compiled `--with-debug` providing very detailed debugging information.
When started with `-e "LOG_LEVEL=info"` the output is quite verbose.
To learn more about this option visit [NGINX docs](http://nginx.org/en/docs/debugging_log.html).

 When done stop the image:
 ```
 make docker-stop
 ```

### Enabling API KEY Management through Redis

This command starts two docker containers: redis and gateway
 ```
 make docker-compose
 ```

### SSH into the running image

```
make docker-attach
```

#### Running the container in Mesos with Marathon

Make an HTTP POST on `http://<marathon-host>/v2/apps` with the following payload.
For optimal performance leave the `network` on `HOST` mode. To learn more about the network modes visit the Docker [documentation](https://docs.docker.com/articles/networking/#how-docker-networks-a-container).

```javascript
{
  "id": "api-gateway",
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "adobeapiplatform/apigateway:latest",
      "forcePullImage": true,
      "network": "HOST"
    }
  },
  "cpus": 4,
  "mem": 4096.0,
  "env": {
    "MARATHON_HOST": "http://<marathon_host>:<marathon_port>"
  },
  "constraints": [  [ "hostname","UNIQUE" ]  ],
  "ports": [ 80 ],
  "healthChecks": [
    {
      "protocol": "HTTP",
      "portIndex": 0,
      "path": "/health-check",
      "gracePeriodSeconds": 3,
      "intervalSeconds": 10,
      "timeoutSeconds": 10
    }
  ],
  "instances": 1
}
```

To run the Gateway only on specific nodes marked with `slave_public` you can add the property bellow to the main JSON object:
```
"acceptedResourceRoles": [ "slave_public" ]
```

##### Auto-discover and register Marathon tasks in the Gateway

To enable auto-discovery in a Mesos with Marathon framework define the following Environment Variables:
```
MARATHON_URL=http://<marathon-url-1>
MARATHON_TASKS=ws-.* ( NOT USED NOW. TBD IF THERE'S A NEED TO FILTER OUT SOME TASKS )
```

So the Docker command is now :
```
docker run --name="apigateway" \
            -p 8080:80 \
            -e "MARATHON_HOST=http://<marathon_host>:<port>/" \
            -e "LOG_LEVEL=info" \
            adobeapiplatform/apigateway:latest
```

