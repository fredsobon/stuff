# KUBE-AUTHENT

## Introduction

This helm installs a solution to authenticate users of our Kubernetes clusters.  
It packages the installation of :
* an identity provider **Dex** (https://github.com/dexidp/dex)
* a Kubeconfig generator **Gangway** (https://github.com/heptiolabs/gangway)

![Authentication Flow](https://github.com/heptiolabs/gangway/blob/master/docs/images/gangway-sequence-diagram.png?raw=true)

In our case **Dex** is configured to connect to our Active Directory, to authenticate users (with email) **and** to fetch their group membership.


> **Dex** doesn't manage authorization. This is the role of the Cluster RBAC.


## Requirements

* [Helm](https://helm.sh/) Tested with >=2.15.0 and <3.0.0
* Kubernetes Tested with 1.16.2

* Kube ApiServer configured with a OIDC provider like this :

```
    - --oidc-ca-file=..../dex-ca.pem
    - --oidc-issuer-url=https://dex.example.com:32000
    - --oidc-client-id=gangway
    - --oidc-username-claim=email
    - --oidc-groups-claim=groups
```

> :warning: **Kube ApiServer will need to communicate properly with Dex in TLS.** The Dex's certificat (and its signing CA) must be trusted by Apiserver Apps/Containers
>* Either, we use inject the CA pem file in containers and set it with the *--oidc-ca-file* apiserver parameter.
>* Or we can trust the CA in the system of your master nodes : it will be mounted in the api-server containers and trusted by default.


## Manage Certificates of HTTPS services

# Using Jetpack's Cert-Manager

This helm doesn't handle the install of Cert-Manager see <https://cert-manager.io/docs/installation/>.  
But it can use Cert-Manager to generate/renew each service TLS certs.  
If *certManager* is *enabled*, you optionally can redefine a Cert-Manager's Cluster Issuer to sign service certs.
And mandatorily you need to set the common names of gangway (*gangwayCert*) and dex (*dexCert*) certs

```yaml
certManager:
  gangwayCert:
    altNames:
    - kubectl.tools.ilius.io
  dexCert:
    altNames:
    - dex.tools.ilius.io
```


# Manually

Generate signed certs/key and push it as TLS Secret objects like this :

```console
kubectl create secret tls <secretname> --cert <crtfile> --key <keyfile> --namespace <appnamespace>
```

By default, you can named it respectively *dex-web-server-tls* and *gangway-cert-tls*.

## Configuration

* Umbrella Chart's configuration

| Parameter                             | Description                                           | Default                   |
| ---------                             | -------------                                         | -------                   |
| `certManager.enabled`                 | Use Jetpack's Cert Manager to create services certs   | `true`                    |
| `certManager.caIssuer`                | Which Cluster Issuer to sign certs                    | `lapin-env-ca-issuer`    |
| `certManager.gangwayCert.altNames`    | Array of allowed FQDNs for the gangway service        | None                      |
| `certManager.dexCert.altNames`        | Array of allowed FQDNs for the dex service            | None                      |

* [configuration of Gangway Helm Charts](https://github.com/helm/charts/blob/master/stable/gangway/README.md)

* [configuration of DEX Helm Charts](https://github.com/helm/charts/blob/master/stable/dex/README.md)
