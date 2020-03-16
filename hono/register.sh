#!/bin/bash
set -e

##################### CONST #####################

APPLICATION_YAML_FILE="/tmp/application.yaml"
HTTP_ADAPTER_CONFIG_FILE_NAME="hono-http-adapter-config.yaml"
HTTP_ADAPTER_CERT_FILE_NAME="cert.pem"
HTTP_ADAPTER_KEY_FILE_NAME="key.pem"
HTTP_ADAPTER_TRUSTSTORE_FILE_NAME="trusted-certs.pem"
HTTP_ADAPTER_CREDENTIALS_FILE_NAME="adapter.credentials"
ROUTER_SERVICES=("messaging" "command")
REGISTRY_SERVICES=("tenant" "registration" "credentials" "deviceConnection")

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

function determineHonoEndpoints() {
  KUBERNETES_NODE_IP=$(kubectl get nodes --output jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  REGISTRY_SERVICE_TYPE=$(kubectl get service -n "$NAMESPACE" hono-service-device-registry-ext --output jsonpath='{.spec.type}')

  case $REGISTRY_SERVICE_TYPE in
    NodePort)
      REGISTRY_IP=$KUBERNETES_NODE_IP
      REGISTRY_AMQPS_PORT=$(kubectl get service -n "$NAMESPACE" hono-service-device-registry-ext --output jsonpath='{.spec.ports[?(@.name=="amqps")].nodePort}')
      ;;
    LoadBalancer)
      REGISTRY_IP=$(kubectl get service -n "$NAMESPACE" hono-service-device-registry-ext --output='jsonpath={.status.loadBalancer.ingress[0].ip}')
      REGISTRY_AMQPS_PORT=$(kubectl get service -n "$NAMESPACE" hono-service-device-registry-ext --output jsonpath='{.spec.ports[?(@.name=="amqps")].port}')
      ;;
  esac

  ROUTER_SERVICE_TYPE=$(kubectl get service -n "$NAMESPACE" hono-dispatch-router-ext --output jsonpath='{.spec.type}')
  case $ROUTER_SERVICE_TYPE in
    NodePort)
      ROUTER_IP=$KUBERNETES_NODE_IP
      ROUTER_PORT_INTERNAL=$(kubectl get service -n "$NAMESPACE" hono-dispatch-router-ext --output jsonpath='{.spec.ports[?(@.name=="internal")].nodePort}')
      ROUTER_PORT_AMQP=$(kubectl get service -n "$NAMESPACE" hono-dispatch-router-ext --output jsonpath='{.spec.ports[?(@.name=="amqp")].nodePort}')
      ;;
    LoadBalancer)
      ROUTER_IP=$(kubectl get service -n "$NAMESPACE" hono-dispatch-router-ext --output='jsonpath={.status.loadBalancer.ingress[0].ip}')
      ROUTER_PORT_AMQP=$(kubectl get service -n "$NAMESPACE" hono-dispatch-router-ext --output jsonpath='{.spec.ports[?(@.name=="amqp")].port}')
      ;;
  esac

}

function routerServicesListToYaml() {
  local FILE=$1
  local HOST=$2
  local PORT=$3
  shift 3
  local SERVICES=$@
  for PREFIX in ${SERVICES[@]}; do
  echo -n "
  ${PREFIX}:
    host: $HOST
    port: $PORT
    amqpHostname: hono-internal
    keyPath: ${CONT_DST}/${HTTP_ADAPTER_KEY_FILE_NAME}
    certPath: ${CONT_DST}/${HTTP_ADAPTER_CERT_FILE_NAME}
    trustStorePath: ${CONT_DST}/${HTTP_ADAPTER_TRUSTSTORE_FILE_NAME}
    hostnameVerificationRequired: false" >> $FILE
  done
}

function registryServicesListToYaml() {
  local FILE=$1
  local HOST=$2
  local PORT=$3
  shift 3
  local SERVICES=$@
  for PREFIX in ${SERVICES[@]}; do
  echo -n "
  ${PREFIX}:
    host: $HOST
    port: $PORT
    credentialsPath: ${CONT_DST}/${HTTP_ADAPTER_CREDENTIALS_FILE_NAME}
    trustStorePath: ${CONT_DST}/${HTTP_ADAPTER_TRUSTSTORE_FILE_NAME}
    hostnameVerificationRequired: false" >> $FILE
  done
}

function createAdapterConfigYaml() {

  # download HTTP adapter key material and trust store
  curl https://raw.githubusercontent.com/eclipse/packages/master/charts/hono/hono-demo-certs-jar/http-adapter-cert.pem > ${SRC}/${HTTP_ADAPTER_CERT_FILE_NAME}
  curl https://raw.githubusercontent.com/eclipse/packages/master/charts/hono/hono-demo-certs-jar/http-adapter-key.pem > ${SRC}/${HTTP_ADAPTER_KEY_FILE_NAME}
  curl https://raw.githubusercontent.com/eclipse/packages/master/charts/hono/hono-demo-certs-jar/trusted-certs.pem > ${SRC}/${HTTP_ADAPTER_TRUSTSTORE_FILE_NAME}
  curl https://raw.githubusercontent.com/eclipse/packages/master/charts/hono/example/http-adapter.credentials > ${SRC}/${HTTP_ADAPTER_CREDENTIALS_FILE_NAME}
  YAML_FILE=${SRC}/${HTTP_ADAPTER_CONFIG_FILE_NAME}

  echo -n "---
hono:
  app:
    maxInstances: 1
  healthCheck:
    insecurePort: 8088
    insecurePortBindAddress: 0.0.0.0
  http:
    bindAddress: 0.0.0.0
    insecurePortEnabled: true
    insecurePortBindAddress: 0.0.0.0
    keyPath: ${CONT_DST}/${HTTP_ADAPTER_KEY_FILE_NAME}
    certPath: ${CONT_DST}/${HTTP_ADAPTER_CERT_FILE_NAME}" > $YAML_FILE

  # Update envs
  determineHonoEndpoints
  routerServicesListToYaml $YAML_FILE $ROUTER_IP $ROUTER_PORT_INTERNAL ${ROUTER_SERVICES[@]}
  registryServicesListToYaml $YAML_FILE $REGISTRY_IP $REGISTRY_AMQPS_PORT ${REGISTRY_SERVICES[@]}
}

function createApplicationYaml(){
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
        port: $ROUTER_PORT_AMQP
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
        x86: eclipse/hono-adapter-http-vertx:1.1.1
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
        value: file://${CONT_DST}/$HTTP_ADAPTER_CONFIG_FILE_NAME
      - key: SPRING_PROFILES_ACTIVE
        value: prod
      - key: LOGGING_CONFIG
        value: classpath:logback-spring.xml" > $APPLICATION_YAML_FILE

  # Update volumes
  echo "
      volumes:
      - hostDestination: $DST
        containerDestination: $CONT_DST
        accessMode: 'r'" >> $APPLICATION_YAML_FILE
}

##################### MAIN #####################

initArgs $@
createAdapterConfigYaml

# Get Agent IP
AGENT_IP=$(iofogctl get agents -n "$NAMESPACE" | grep "$AGENT" | awk '{print $4}')
if [ -z "$AGENT_IP" ]; then
  echo "Could not find ioFog Agent $AGENT IP address"
  exit 1
fi
# Rsync files to Agent
rsync -r $SRC $USER@$AGENT_IP:$DST

createApplicationYaml
