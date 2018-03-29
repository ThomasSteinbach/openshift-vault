#!/bin/bash

if [ -z $1 ]; then
  echo "Please call this script with the vault login token as first argument"
  exit 1
fi

sudo oc login -u system:admin > /dev/null

VAULT_NODE_PORT=$(sudo oc get svc/vault -o=jsonpath='{@.spec.ports[0].nodePort}' -n vault)
export VAULT_ADDR="http://127.0.0.1:$VAULT_NODE_PORT"

vault login "$1" > /dev/null
