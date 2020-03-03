#!/bin/bash
set -e

##################### CONST #####################

TYPE="http" # http || mqtt
ADAPTER_YAML_FILE="/tmp/hono-http-adapter.yaml"
ROUTER_SERVICES=("HONO_MESSAGING" "HONO_COMMAND")
REGISTRY_SERVICES=("HONO_TENANT" "HONO_REGISTRATION" "HONO_CREDENTIALS" "HONO_DEVICECONNECTION")
REGISTRY_AMQP_PORT=5672
REGISTRY_HTTP_PORT=28080
ROUTER_PORT=15672
ADAPTER_USERNAME="http-adapter@HONO"
ADAPTER_PASSWORD="http-secret"

##################### FUNC #####################

function initArgs(){
  ARG_COUNT=5
  if [ $# -ne $ARG_COUNT ]; then
      echo "$ARG_COUNT arguments are required: <namespace> <agent-name> <src-dir> <dest-dir> <container-dest-dir>"
      exit 1
  fi
  NAMESPACE=$1
  AGENT=$2
  SRC=$3
  DST=$4
  CONT_DST=$5
}

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

function createAdapterYaml(){
  echo -n "---
  apiVersion: iofog.org/v1
  kind: Application
  metadata:
    name: hono
  spec:
    routes:
    - from: heart-rate-monitor
      to: iomessage-to-http-adapter
    - from: amqp-to-iomessage
      to: heart-rate-viewer
    microservices:
    - name: heart-rate-monitor
      agent:
        name: $AGENT
        config:
          bluetoothEnabled: false # this will install the iofog/restblue microservice
          abstractedHardwareEnabled: false
      images:
        arm: edgeworx/healthcare-heart-rate:arm-v1
        x86: edgeworx/healthcare-heart-rate:x86-v1
      config:
        test_mode: true
        data_label: Anonymous Person
    - name: heart-rate-viewer
      agent:
        name: $AGENT
      images:
        arm: edgeworx/healthcare-heart-rate-ui:arm
        x86: edgeworx/healthcare-heart-rate-ui:x86
      ports:
      - external: 5000 # You will be able to access the ui on <AGENT_IP>:5000
        internal: 80 # The ui is listening on port 80. Do not edit this.
    - name: amqp-to-iomessage
      rootHostAccess: true
      agent:
        name: $AGENT
      config:
        username: consumer@HONO
        password: verysecret
        port: $ROUTER_PORT
        host: $ROUTER_IP
        queue: event/DEFAULT_TENANT
      images:
        x86: edgeworx/amqp-to-iomessage-adapter:latest
    - name: iomessage-to-http-adapter
      agent:
        name: $AGENT
      config:
        host: localhost
      rootHostAccess: true
      images:
        x86: edgeworx/iomsg-http-adapter:latest
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
        value: 0.0.0.0
      - key: HONO_HTTP_INSECURE_PORT_ENABLED
        value: true
      - key: HONO_HTTP_AUTHENTICATION_REQUIRED
        value: false" > $ADAPTER_YAML_FILE

  # Update envs
  serviceListToEnv $ROUTER_IP $ROUTER_PORT io-fog ${ROUTER_SERVICES[@]}
  serviceListToEnv $REGISTRY_IP $REGISTRY_AMQP_PORT hono ${REGISTRY_SERVICES[@]} 

  # Update volumes
  echo "
      volumes:
      - hostDestination: $DST
        containerDestination: $CONT_DST
        accessMode: 'r'" >> $ADAPTER_YAML_FILE
}

##################### MAIN #####################

initArgs $@

REGISTRY_IP=$(kubectl get svc | grep hono-service-device-registry-ext | awk '{print $4}' | tr -d '"')
ROUTER_IP=$(kubectl get svc | grep hono-dispatch-router-ext | awk '{print $4}' | tr -d '"')

# Get Agent IP
AGENT_IP=$(iofogctl get agents -n "$NAMESPACE" | grep "$AGENT" | awk '{print $4}')
if [ -z "$AGENT_IP" ]; then
  echo "Could not find ioFog Agent $AGENT IP address"
  exit 1
fi
# Rsync file to Agent
rsync -r $SRC $USER@$AGENT_IP:$DST

createAdapterYaml
