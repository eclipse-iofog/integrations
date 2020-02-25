<img src="https://blog.bosch-si.com/wp-content/uploads/HONO-Logo.png" width="100" height="100">

# Deploying Hono onto ioFog

You will need to start by setting up and preparing your Kubernetes cluster with an ioFog 
control plane. Instructions for doing so 
[can be found here](https://iofog.org/docs/1.3.0/remote-deployment/prepare-your-kubernetes-cluster.html). 

Assuming you have an ioFog ECN up and running, you need to:

1. Deploy Hono to Kubernetes using Helm
2. Generate an ioFog Microservice YAML spec for Hono deployment
3. Deploy Hono HTTP Adapter to ioFog

## Deploy Hono to your Kubernetes cluster using Helm Chart

```bash
kubectl create namespace hono
kubectl config set-context --current --namespace hono
helm install hono helm/eclipse-hono/ --dependency-update --namespace hono
```

## Generate ioFog Microservice YAML for HONO HTTP Adapter

The [register.sh](register.sh) script can be used to automate the generation of your ioFog application
installation file.

```bash
./register.sh
cat /tmp/hono-http-adapter.yaml
```

## Deploy Hono HTTP Adapter to ioFog Agent

If you have not installed `iofogctl` you can find 
[installation instructions here](https://iofog.org/docs/1.3.0/iofogctl/usage.html).

```bash
iofogctl deploy -f /tmp/hono-http-adapter.yaml -n hono
```

## Check out your new hotness

```bash
iofogctl get all -n hono
```
