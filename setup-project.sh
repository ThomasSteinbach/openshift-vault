oc new-project vault || oc project vault
sudo oc login -u system:admin
sudo oc adm policy add-scc-to-user anyuid -z default -n vault
oc-apply
echo "
 The deployment should work, but the 'unseal' job should currently fail.
 Finally you have to
 * entering the vault pod (oc rsh dc/vault)
 * initializing vault, e.g.: vault operator init -key-shares=1 -key-threshold=1
 * Store the unseal key in your keepass!
 * Store the root token in your keepass!
 * create following OpenShift secret containing the unseal key:
   oc create secret generic vault --from-literal=STARTUP_UNSEAL_TOKEN=<unseal-key>
   oc rollout latest dc/vault
 Now the unseal job should work for every new deployment.
"
