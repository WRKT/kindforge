# Velero Toolbox

A simple Helm chart to deploy a Velero CLI toolbox pod. Use this pod to interact with your Velero installation without installing the CLI locally.

## Features

* Downloads and installs the Velero CLI (version follows `appVersion` in `Chart.yaml`).
* Runs as a long-lived pod you can `exec` into.
* Preconfigured ServiceAccount with `cluster-admin` rights (adjust RBAC as needed).

## Prerequisites

* Kubernetes 1.20+ cluster
* Helm 3.x
* An existing Velero installation 

## Installation

```bash
# Clone this repository
git clone https://github.com/WRKT/velero-toolbox

# Add the chart 
helm install velero-toolbox ./velero-toolbox --namespace velero --create-namespace
```

Verify the pod is running:

```bash
kubectl get pods -n velero -l app=velero-toolbox # Name of the release
```

## Usage

Exec into the toolbox pod and run Velero commands:

```bash
kubectl exec -n velero -it deploy/velero-client -- sh

# Inside the pod
velero version
velero backup get
velero restore get
```
