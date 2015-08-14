  apigateway
=============
A performant API Gateway based on Openresty and Nginx.


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
 The main API Gateway process is exposed to port 8080. To test that the Gateway works see its `health-check`:
 ```
  $ curl http://192.168.59.103:8080/health-check
    API-Platform is running!
 ```
 If you're up for a quick performance test, you can play with Apache Benchmark via Docker:

 ```
  docker run jordi/ab ab -k -n 200000 -c 500 http://192.168.59.103:8080/health-check
 ```

 When done stop the image:
 ```
 make docker-stop
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
      "image": "apiplatform/apigateway:latest",
      "forcePullImage": true,
      "network": "HOST"
    }
  },
  "cpus": 4,
  "mem": 4096.0,
  "env": {
    "MARATHON_HOST": "http://<marathon_host>:<marathon_port>"
  },
  "constraints": [
    [
      "hostname",
      "UNIQUE"
    ]
  ],
  "acceptedResourceRoles": ["slave_public"],
  "ports": [
    80
  ],
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

##### Auto-discover and register Marathon tasks in the Gateway

To enable auto-discovery in a Mesos with Marathon framework define the following Environment Variables:
```
MARATHON_URL=http://<marathon-url-1>
MARATHON_TASKS=ws-.* ( NOT USED NOW. TBD IF THERE'S A NEED TO FILTER OUT SOME TASKS )
```

So the Docker command is now :
```
docker run  -p 8080:80 \
            -e "MARATHON_HOST=http://<marathon_host>:<marathon_port>" \
            -v `pwd`/api-gateway-config:/etc/api-gateway apiplatform/api-platform-box:latest
```

