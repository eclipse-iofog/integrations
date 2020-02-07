#!/bin/bash
set -e

TYPE="http" # http || mqtt
ADAPTER_YAML_FILE="/tmp/hono-http-adapter.yaml"

REGISTRY_IP=$(kubectl get svc | grep hono-service-device-registry-ext | awk '{print $4}' | tr -d '"')
REGISTRY_AMQP_PORT=5672
REGISTRY_HTTP_PORT=28080
ROUTER_IP=$(kubectl get svc | grep hono-dispatch-router-ext | awk '{print $4}' | tr -d '"')
ROUTER_PORT=15672
ADAPTER_USERNAME="http-adapter@HONO"
ADAPTER_PASSWORD="http-secret"

AGENT=$(iofogctl get agents -n iofog| grep RUNNING | awk '{print $1}' | head -1)
if [ -z "$AGENT" ]; then
  echo "Could not find ioFog Agent with RUNNING status"
  exit 1
fi

function serviceListToEnv() {
  local HOST=$1
  local PORT=$2
  local VIRTUAL_HOST=$3
  shift 3
  local SERVICES=$@
  for PREFIX in ${SERVICES[@]}; do
  echo -n "
    - key: ${PREFIX}_HOST
      value: $HOST
    - key: ${PREFIX}_PORT
      value: $PORT
    - key: ${PREFIX}_AMQP_HOSTNAME
      value: $VIRTUAL_HOST
    - key: ${PREFIX}_USERNAME
      value: $ADAPTER_USERNAME
    - key: ${PREFIX}_PASSWORD
      value: $ADAPTER_PASSWORD
    - key: ${PREFIX}_HOSTNAME_VERIFICATION_REQUIRED
      value: false" >> $ADAPTER_YAML_FILE
  done
}

echo -n "---
apiVersion: iofog.org/v1
kind: Application
metadata:
  name: hono
spec:
  microservices:
  - name: http-adapter
    agent:
      name: $AGENT
    images:
      x86: index.docker.io/eclipse/hono-adapter-$TYPE-vertx:1.0.3
    rootHostAccess: true
    ports:
    - internal: 8088
      external: 8088
    - internal: 8080
      external: 8080
    - internal: 8443
      external: 8443
    env:
    - key: SPRING_CONFIG_LOCATION
      value: file:///etc/hono/
    - key: SPRING_PROFILES_ACTIVE
      value: dev
    - key: LOGGING_CONFIG
      value: classpath:logback-spring.xml
    - key: HONO_HEALTHCHECK_INSECUREPORTBINDADDRESS
      value: "0.0.0.0"
    - key: HONO_HTTP_INSECURE_PORT_ENABLED
      value: true" > $ADAPTER_YAML_FILE

ROUTER_SERVICES=("HONO_MESSAGING" "HONO_COMMAND")
REGISTRY_SERVICES=("HONO_TENANT" "HONO_REGISTRATION" "HONO_CREDENTIALS" "HONO_DEVICECONNECTION")

serviceListToEnv $ROUTER_IP $ROUTER_PORT io-fog ${ROUTER_SERVICES[@]}
serviceListToEnv $REGISTRY_IP $REGISTRY_AMQP_PORT hono ${REGISTRY_SERVICES[@]} 
