#!/bin/bash
set -e

REGISTRY_IP=$(kubectl get svc | grep hono-service-device-registry-ext | awk '{print $4}' | tr -d '"')
ROUTER_IP=$(kubectl get svc | grep hono-dispatch-router-ext | awk '{print $4}' | tr -d '"')
MY_TENANT=$(curl -si -X POST http://$REGISTRY_IP:28080/v1/tenants | tail -n1 | jq .id | tr -d '"')
MY_DEVICE=$(curl -si -X POST http://$REGISTRY_IP:28080/v1/devices/$MY_TENANT | tail -n1 | jq .id | tr -d '"')
MY_PWD=my-pwd
curl -i -X PUT -H "content-type: application/json" --data-binary '[{
  "type": "hashed-password",
  "auth-id": "'$MY_DEVICE'",
  "secrets": [{
      "pwd-plain": "'$MY_PWD'"
  }]
}]' http://$REGISTRY_IP:28080/v1/credentials/$MY_TENANT/$MY_DEVICE

ADAPTER_YAML_FILE="/tmp/hono-http-adapter.yaml"

echo "REGISTRY_IP=$REGISTRY_IP
MY_TENANT=$MY_TENANT
MY_DEVICE=$MY_DEVICE
MY_PWD=$MY_PWD"

echo -n "---
apiVersion: iofog.org/v1
kind: Application
metadata:
  name: hono
spec:
  microservices:
  - name: http-adapter
    agent:
      name: local-agent
    images:
      x86: index.docker.io/eclipse/hono-adapter-http-vertx:1.0.3
    container:
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
      - key: HONO_HTTP_INSECURE_PORT_ENABLED
        value: true
      - key: HONO_MESSAGING_PORT
        value: 15672
      - key: HONO_MESSAGING_HOST
        value: $ROUTER_IP
      - key: HONO_MESSAGING_USERNAME
        value: ${MY_DEVICE}@${MY_TENANT}
      - key: HONO_MESSAGING_PASSWORD
        value: ${MY_PWD}
      - key: HONO_MESSAGING_HOSTNAME_VERIFICATION_REQUIRED
        value: false" > $ADAPTER_YAML_FILE

SERVICES=("HONO_TENANT" "HONO_REGISTRATION" "HONO_CREDENTIALS" "HONO_DEVICE_CONNECTION")

for PREFIX in "${SERVICES[@]}"; do
echo -n "
      - key: ${PREFIX}_HOST
        value: $REGISTRY_IP
      - key: ${PREFIX}_PORT
        value: 28080
      - key: ${PREFIX}_USERNAME
        value: ${MY_DEVICE}@${MY_TENANT}
      - key: ${PREFIX}_PASSWORD
        value: ${MY_PWD}
      - key: ${PREFIX}_HOSTNAME_VERIFICATION_REQUIRED
        value: false" >> $ADAPTER_YAML_FILE
done
