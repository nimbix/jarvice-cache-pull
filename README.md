# JARVICE Cache Pull 

Kubernetes daemon set for JARVICE docker image cache

## Getting Started

This project will build and deploy jarvice-cache-pull daemonset for JARVICE

### Prerequisites

This project requires:

* kubectl
* docker
* ssh

**Note** remote access to ppc64le host required (with same prerequisites as above)

For Ubuntu:

```
apt-get install ssh snapd
snap install kubectl --classic
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
DEBARCH=$(dpkg --print-architecture) && echo "deb [arch=$DEBARCH] https://download.docker.com/linux/ubuntu ${LSB_REL_NAME} stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install docker-ce
```

### Building 

The `build-docker.sh` script is used to build the required Docker images and create a multi-arch manifest list.

Required arguments:

* `-h <ppc64le-host>`     := username and host for remote ppc64le host (e.g. khill@ppc64le.example.org)
* `-r <docker-repo>`      := Docker repository for project (e.g. quay.io/khill/jarvice-cache-pull)
* `-R <docker-registry>`  := Docker registry (e.g. quay.io)
* `-u <docker-user>`      := Docker registry username
* `-U <ubuntu-release>`   := Ubuntu release for Docker image (e.g. bionic)
* `-g <github-repo>`      := GitHub repository for this project (e.g. github.com/nimbix/jarvice-cache-pull)
* `-t <github-token>`     := GitHub username and [access token](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) (e.g. khill:`<token>`)

## Deployment

This daemon set uses K8s Config Map and secrets to configure which Docker images to pull into a workers cache. The config map `image-cache` list the desired Docker images to cache using json format.

The default Docker secret used is `jarvice-docker`. Additional Docker secrets can be added following [these instructions](#add-docker-registry-user)

### Image Cache Format 

The `image-cache` Config Map consist of a json file and `interval` literal: 

Image Object

| Key  | Value  | Description |
|---|---|---|
| `ref`  | `string`  | Name of Docker image |
| `registry`  | `string`  | Docker registry for image |
| `private`  | `bool`  | Indicates private image (require login) |
| `config`  | `string`  | Docker secret (default `jarvice-docker`) |
| `arch`  | `json object` | Pointer for multi-arch support |

Arch Object

| Key | Value | Description |
|---|---|---|
| `amd64` | `string` | amd64 Docker image to pull from registry |
| `ppc64le` | `string` | ppc64le Docker image to pull from registry |

Example

```
[
    {
        "ref": "ubuntu:xenial",
        "registry": "docker.io",
        "private": false,
        "config": "jarvice-docker",
        "arch": {
            "amd64": "docker.io/library/ubuntu:xenial",
            "ppc64le": "docker.io/ppc64le/ubuntu:xenial"
        }
    },
    {
        "ref": "fail-test",
        "registry": "docker.io",
        "private": true,
        "config": "jarvice-docker",
        "arch": {
            "amd64": "docker.io/kenhill/abc123:test"
        }
    }
]
```

Literal

`interval`  := delay in seconds between cache update

### Create K8s Daemon Set

1) Create image json file at `config/image.config`
2) Create `image-cache` Config Map
```
kubectl --namespace=<namespace> create configmap image-cache --from-file config/ --from-literal interval=300
```
3) Create Daemon Set
```
kubectl create -f jarvice-cache-pull.yaml
```

### Update Image Cache

1) Update `config/image.config`
2) Replace Config Map
```
kubectl --namespace=<namespace> create configmap image-cache --from-file config/ --from-literal interval=300 -o yaml --dry-run | kubectl replace -f -
```

### Add Docker Registry User

1) Create new `kubernetes.io/dockerconfigjson` secret in appropriate namespace
2) Update `jarvice-cache-pull.yaml` to include new secret
```
        volumeMounts:
...
        - name: jarvice-docker 
          mountPath: /root/.docker/jarvice-docker/config.json
          subPath: config.json
        - name: <new-secret>
          mountPath: /root/.docker/<new-config>/config.json
          subPath: config.json
      volumes:
...
      - name: jarvice-docker
        secret:
          secretName: jarvice-docker
          items:
          - key: ".dockerconfigjson"
            path: config.json
      - name: <new-secret> 
        secret:
          secretName: <k8s-secret>
          items:
          - key: ".dockerconfigjson"
            path: config.json
``` 

**Note** `<new-config>` must match the `config` key in `config/image.json`

## Authors

* **Kenneth Hill** - *Initial work* - ken.hill@nimbix.net

## License

This project uses an Open Source license - see the [LICENSE.md](LICENSE.md) file for details

