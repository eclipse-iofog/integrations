#!/bin/bash
set -e

ADAPTER_YAML_FILE="/tmp/hono-http-adapter.yaml"

AUTH_IP=$(kubectl get svc | grep hono-service-auth | awk '{print $4}' | tr -d '"' | head -n 1)
AUTH_PORT=5671
REGISTRY_IP=$(kubectl get svc | grep hono-service-device-registry-ext | awk '{print $4}' | tr -d '"')
REGISTRY_AMQP_PORT=5672
REGISTRY_HTTP_PORT=28080
ROUTER_IP=$(kubectl get svc | grep hono-dispatch-router-ext | awk '{print $4}' | tr -d '"')
ROUTER_PORT=15672
ADAPTER_USERNAME="http-adapter@HONO"
ADAPTER_PASSWORD="http-secret"
MY_TENANT=$(curl -si -X POST http://$REGISTRY_IP:$REGISTRY_HTTP_PORT/v1/tenants | tail -n1 | jq .id | tr -d '"')
MY_DEVICE=$(curl -si -X POST http://$REGISTRY_IP:$REGISTRY_HTTP_PORT/v1/devices/$MY_TENANT | tail -n1 | jq .id | tr -d '"')
MY_PWD=my-pwd
curl -i -X PUT -H "content-type: application/json" --data-binary '[{
  "type": "hashed-password",
  "auth-id": "'$MY_DEVICE'",
  "secrets": [{
      "pwd-plain": "'$MY_PWD'"
  }]
}]' http://$REGISTRY_IP:$REGISTRY_HTTP_PORT/v1/credentials/$MY_TENANT/$MY_DEVICE


AGENT=$(iofogctl get agents | grep RUNNING | awk '{print $1}' | head -1)
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
  - name: edge-router
    agent:
      name: $AGENT
    images:
      x86: quay.io/interconnectedcloud/qdrouterd:latest
    container:
      ports:
      - internal: 5672
        external: 5672
      env:
      - key: QDROUTERD_CONF
        value: \"router {\n  mode: edge\n  id: hono-edge-router\n}\n\nauthServicePlugin {\n  host: $AUTH_IP\n  port: $AUTH_PORT\n  sslProfile: internal\n}\n\nlistener {\n  role: normal\n  host: 0.0.0.0\n  port: 5672\n  saslMechanisms: PLAIN\n  saslPlugin: Hono Auth\n}\n\nconnector {\n  host: $ROUTER_IP\n  port: $ROUTER_PORT\n  role: edge\n  saslMechanisms: PLAIN\n  saslUsername: $ADAPTER_USERNAME\n  saslPassword: pass:$ADAPTER_PASSWORD\n}\n\"
  - name: http-adapter
    agent:
      name: $AGENT
    images:
      x86: index.docker.io/eclipse/hono-adapter-http-vertx:1.0.3
    container:
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

serviceListToEnv localhost 5672 io-fog ${ROUTER_SERVICES[@]}
serviceListToEnv $REGISTRY_IP $REGISTRY_AMQP_PORT hono ${REGISTRY_SERVICES[@]} 
