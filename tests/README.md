# Manual test

This is for manually testing the image under a Jenkins in K3D cluster.

## Creating the cluster

```bash
K3D_FIX_DNS=1 k3d cluster create
```

## Installing Dynamic Hostports

After creating the cluster, you can install [dynamic-hostports](https://github.com/felipecrs/dynamic-hostports-k8s) with:

```bash
kubectl apply -f https://raw.githubusercontent.com/felipecrs/dynamic-hostports-k8s/master/deploy.yaml
```

## Installing Jenkins

```bash
TAG=latest helmfile sync -f tests/helmfile.yaml --debug

echo http://127.0.0.1:8080
kubectl --namespace default port-forward svc/jenkins 8080:8080
```

Jenkins will be available at <http://127.0.0.1:8080>.

You can change the `jenkins-agent-dind` tag with the `TAG` environment variable.

## Running the tests

There will be a job in Jenkins called `test-agent`. Simply run it.
