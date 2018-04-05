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

OC_PROJECTS=$(vault list secret/openshift | tail -n +3 | sed 's/\/$//')

for project in $OC_PROJECTS; do
  echo -e "\n== Secrets in $project =="

  OC_SECRETS=$(vault list "secret/openshift/$project" | tail -n +3 | sed 's/\/$//')

  for secret in $OC_SECRETS; do

    createTempFiles
    sudo oc export secret "$secret" -n  "$project" 1> /tmp/.oc.tmp 2> /tmp/vault2ocerror
    rc=$?
    if [[ $rc != 0 ]]; then
      if [[ $(cat /tmp/vault2ocerror) =  *"namespaces"*"not found"* ]]; then
        read -p "Project $project does not exist in OpenShift. Create? (yes/no) " createproject
        if [ "$createproject" == 'yes' ]; then
          sudo oc new-project "$project"
          vault read -field content "secret/openshift/$project/$secret" | sudo oc create -n "$project" -f -
          cleanup
          continue
        fi
      elif [[ $(cat /tmp/vault2ocerror) =  *"secrets"*"not found"* ]]; then
        vault read -field content "secret/openshift/$project/$secret" | sudo oc create -n "$project" -f -
        cleanup
        continue
      else
        echo "Error $(cat /tmp/oc2vaulterror)"
        cleanup
        exit $rc
      fi
    fi

    vault read -field content "secret/openshift/$project/$secret" 1> /tmp/.vault.tmp
    # add linebreak at end of file, which got lost through vault
    sed -i -e '$a\' /tmp/.vault.tmp

    if ! diff -q /tmp/.vault.tmp /tmp/.oc.tmp &>/dev/null; then
      echo 'The secrets in Vault and OpenShift are different:'
      echo 'Vault <<------>> OpenShift'
      diff -y /tmp/.vault.tmp /tmp/.oc.tmp

      read -p 'Do you want to overwrite the one in OpenShift? (yes/no) ' answer
      if [ "$answer" == 'yes' ]; then
        vault read -field content "secret/openshift/$project/$secret" | sudo oc apply -n "$project" -f -
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
