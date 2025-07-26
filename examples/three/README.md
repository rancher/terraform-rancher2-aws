# Three

This module was developed working closely with specific customer feedback.

## Goals

- three node HA Rancher cluster where each node has all Kubernetes roles
- the ability to specify a helm repo for the Rancher install (specifically the prime repo)
- the ability to specify custom values for Rancher helm chart
- the ability to use a remote backend, updating the infrastructure using a CI tool
- the ability to use self-signed certificates for Rancher ingress TLS
