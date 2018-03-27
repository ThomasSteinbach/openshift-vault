Hashicorp Vault on OpenShift
============================

This repository is simply deploying [Hashicorp Vault](https://www.vaultproject.io/) on OpenShift.

For usage read the [README_oc2git](README_oc2git.md) of the oc2git project.

For deployment from scratch read the contents of the [setup-project.sh](setup-project.sh).

Notes
-----

This project uses Persistent Volume Claims. Deleting the PVCs and recreating all OpenShift objcets will lead to data loss.
