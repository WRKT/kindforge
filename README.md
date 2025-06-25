# 🔧 KindForge

KindForge is a reproducible infrastructure toolkit that creates a secure, test-ready Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/), `mkcert`, and `cert-manager`.

It is designed for Kubernetes enthusias, and developers who want:

- Local HTTPS endpoints via TLS automation with `mkcert`
- Built-in observability stack (Grafana, Prometheus, optional)
- Full automation via shell and Makefile scripts
- A one-command bootstrap to go from “Docker-only” to “Kubernetes-ready”

> ✨ Whether you're testing TLS, playing with Ingress, or preparing CI/CD pipelines — KindForge gives you a repeatable, versioned foundation.

---

## Features

- Kind cluster with custom name, port mapping, and no default CNI
- TLS certificate automation using `mkcert`
- Cert-manager with CA-based ClusterIssuer
- HTTPS-ready Ingress
- Prometheus + Grafana stack (optional)

---

## Getting Started

> 🔧 Requirements: Docker, Bash, Helm, `mkcert`, `kubectl`

```shell
git clone https://github.com/WRKT/kindforge.git
cd kindforge
make bootstrap
```
