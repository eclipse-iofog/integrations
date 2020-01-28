#!/bin/sh

set -x
set -e

REGISTRY_IP=$(kubectl get svc | grep hono-service-device-registry-ext | awk '{print $4}' | tr -d '"')
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
