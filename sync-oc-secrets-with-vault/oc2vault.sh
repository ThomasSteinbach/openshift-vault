#!/bin/bash

origin=$(dirname $(readlink -f "$0"))

function cleanup {
  rm -f /tmp/.vault.tmp &>/dev/null
  rm -f /tmp/.oc.tmp &>/dev/null
}

function createTempFiles {
  touch /tmp/.vault.tmp
  touch /tmp/.oc.tmp
  chmod 0700 /tmp/.vault.tmp
  chmod 0700 /tmp/.oc.tmp
}

source "$origin/vault-login.sh"

OC_PROJECTS=$(sudo oc get projects -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
OC_PROJECTS=$(echo ${OC_PROJECTS[@]} | awk '{gsub(/(default|kube-public|kube-system|openshift|openshift-infra|openshift-node)( |$)/,"")}1')

for project in $OC_PROJECTS; do
  echo -e "\n== Secrets in $project =="

  OC_SECRETS=$(sudo oc get secrets -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' -n $project)
  OC_SECRETS=$(echo ${OC_SECRETS[@]} | awk '{gsub(/(builder|default|deployer)-(dockercfg|token)-\w*( |$)/,"")}1')

  if [[ ${#OC_SECRETS[@]} == 1 && ${OC_SECRETS[0]} == '' ]]; then
    echo 'There are no secrets in this project'
    continue
  fi

  for secret in $OC_SECRETS; do

    createTempFiles
    vault read -field content "secret/openshift/$project/$secret" 1> /tmp/.vault.tmp 2> /tmp/oc2vaulterror
    rc=$?
    if [[ $rc != 0 ]]; then
      if [[ $(cat /tmp/oc2vaulterror) = "No value found at"* ]]; then
        echo "Add new value to vault: secret/openshift/$project/$secret"
        vault write "secret/openshift/$project/$secret" content="$(sudo oc export secret $secret -n $project)"
        cleanup
        continue
      else
        echo "Error $(cat /tmp/oc2vaulterror)"
        cleanup
        exit $rc
      fi
    fi

    # add linebreak at end of file, which got lost through vault
    sed -i -e '$a\' /tmp/.vault.tmp

    sudo oc export secret $secret -n $project > /tmp/.oc.tmp

    if ! diff -q /tmp/.oc.tmp /tmp/.vault.tmp &>/dev/null; then
      echo 'The secrets in OpenShift and Vault are different:'
      echo 'OpenShift <<------>> Vault'
      diff -y /tmp/.oc.tmp /tmp/.vault.tmp

      read -p 'Do you want to overwrite the one in Vault? (yes/no) ' answer
      if [ "$answer" == 'yes' ]; then
        vault write "secret/openshift/$project/$secret" content="$(cat /tmp/.oc.tmp)"
        cleanup
        continue
      else
        echo "SKIPPED! Answer was '$answer' but not 'yes'"
        cleanup
        continue
      fi
    else
      echo "The secret $secret is up to date."
    fi
  done
done

cleanup
