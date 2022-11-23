# Manual test

This is for manually testing the image under a Jenkins in K3D cluster.

## Creating the cluster

```bash
K3D_FIX_DNS=1 k3d cluster create
```

## Installing Jenkins

```bash
helmfile sync -f tests/helmfile.yaml --debug

echo http://127.0.0.1:8080
kubectl --namespace default port-forward svc/jenkins 8080:8080
```

Jenkins will be available at <http://127.0.0.1:8080>.

## Running the tests

There will be a job in Jenkins called `test-agent`. Simply run it.
