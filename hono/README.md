# ioFog w/ Hono

Assuming you have an ioFog ECN up and running...
1. Deploy Hono to Kubernetes cluster using its Helm chart
2. Run register.sh to generate an ioFog Microservice YAML file for Hono HTTP Adapter
3. Deploy Hono HTTP Adapter to edge

## Deploy Hono to Kubernetes cluster using Helm Chart

```bash
kubectl create namespace hono
kubectl config set-context --current --namespace hono
helm install hono eclipse-hono/ --dependency-update --namespace hono
```

## Generate ioFog Microservice YAML file for HONO HTTP Adapter

```bash
./register.sh
cat /tmp/hono-http-adapter.yaml
```

## Deploy Hono HTTP Adapter to ioFog Agent

```bash
iofogctl deploy -f  /tmp/hono-http-adapter.yaml
```
