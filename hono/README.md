<img src="https://blog.bosch-si.com/wp-content/uploads/HONO-Logo.png" width="100" height="100">

# Deploying Hono onto ioFog

You will need to start by setting up and preparing your Kubernetes cluster with an ioFog 
control plane. Instructions for doing so 
[can be found here](https://iofog.org/docs/1.3.0/remote-deployment/prepare-your-kubernetes-cluster.html). 

Assuming you have an ioFog ECN up and running, you need to:

1. Deploy Hono to Kubernetes using Helm
2. Generate an ioFog Microservice YAML spec for Hono deployment
3. Deploy Hono HTTP Adapter to ioFog

## Install Hono to your Kubernetes cluster using Helm Chart

Please make sure that you meet the [prerequisites for installing Hono's Helm chart](https://github.com/eclipse/packages/blob/master/charts/hono/README.md).

Then install the chart using `hono` as the release name. Make sure to replace `my-ns` with the name of the ioFog
name space you are using for your ECN.

```bash
kubectl create namespace my-ns
helm install --dependency-update -n my-ns --set adapters.externalAdaptersEnabled=true hono eclipse-iot/hono
```

## Generate ioFog Microservice YAML for HONO HTTP Adapter

The [register.sh](register.sh) script can be used to automate the generation of your ioFog application
installation file and the configuration files required by Hono's HTTP adapter running on the agent.
Make sure to replace the `my-ns` argument with the name of the name space that you have used for your
ioFog ECN and into which you have installed Hono in your Kubernetes cluster.

```bash
mkdir /tmp/hono-config
./register.sh my-ns my-agent /tmp/hono-config /tmp/hono-config /etc/hono
cat /tmp/hono-http-adapter.yaml
```

## Deploy Hono HTTP Adapter to ioFog Agent

If you have not installed `iofogctl` you can find 
[installation instructions here](https://iofog.org/docs/1.3.0/iofogctl/usage.html).

Again, make sure to replace the `my-ns` parameter value with the name of the name space that you have
used for your ioFog ECN.

```bash
iofogctl deploy -f /tmp/application.yaml -n my-ns
```

## Check out your new hotness

```bash
iofogctl get all -n my-ns
```
