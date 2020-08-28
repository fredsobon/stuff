![alt text][logo]

[logo]: img/proxmox.png "Helm proxmox monitoring repo"

----
## Présentation générale :

Ce projet gitlab va permettre de fournir un chart helm permettant de monitorer les hyperviseurs et les vms d'un cluster proxmox.
> :warning: Ici nous estimons que le cluster kubernetes est installé fonctionnel et que prometheus est déployé dans le cluster.
Il est également nécéssaire de s'assurer qu'un user proxmox (pve_exporter) est bien créer sur nos clusters promox. Ce compte en RO permet d'interroger l'api proxmox. 

----
Pour info complémentaire : un répertoire contenant des dashboard grafana est inclu dans le repo :
 ` ls resources/grafana_dashboard `

----
>:warning: Il est fortement conseillé de déployer le helm dans le même namespace que le prometheus.

----

## Présentation du chart :

Ce chart dédié au monitoring d'un cluster proxmox va s'articuler sur deux composants principaux 
- node exporter prometheus 
- pve exporter 

**node exporter** 

ce composant va nous permettre de récupérer les métriques système de nos hyperviseurs.
Sur chacun de ceux-ci le pkg "prometheus-node-exporter" est installé.

Les objets kubernetes suivants (service, endpoints et servicemonitor) vont nous permettre de récupérer les métriques exposées par les hyperviseurs afin de les mettre à dispo pour un affichage dans grafana.


**pve exporter**

Ce composant va nous permettre d'interroger et remonter les informations disponibles dans l'api proxmox
Le code à la base de ce composant est disponible https://github.com/prometheus-pve/prometheus-pve-exporter

Plusieurs objects kubernetes vont permettre de récupérer les métriques des hyperviseurs et vms proxmox via sont api.

- un deployment qui va instancier un pod executant le pve exporter 
- un service relatif à ce déployment
- un servicemonitor definissant le job associé dans prometheus
- un endpoints comportant la liste des hyperviseurs du cluster à monitorer 
- un service associé à ce endpoints

ces deux derniers objets vont être utilisés uniquement pour requetter les hyperviseurs via un fqdn dont chacun d'entre eux possedera uen entrée dns (via le mécanisme interne de kubernetes.) 


Le requettage se fera schématiquement comme suivant :

`curl http://<service-pve-exporter>:<port>/pve?target="<service-dns-hyperviseur"

exemple : 

`curl -s http://recette-newyork-proxmox-monit-pve-exporter:9221/pve?target="recette-newyork-proxmox-monit-pve-exporter-hypervisor"`

`# HELP pve_up Node/VM/CT-Status is online/running`

`# TYPE pve_up gauge`

`pve_up{id="cluster/kubeRCnewyork"} 1.0`

`pve_up{id="node/virtrc18u"} 1.0`

`...`



exemples :

- set up du helm chart et déployement pour l'environnement sandbox :

` helm install proxmox-monitoring . -f values.yaml -f helm_vars/sandbox/values.yaml `

- upgrade du chart déployé sous le nom proxmox-monitoring pour l'environnement sandbox :

` helm upgrade proxmox-monitoring . -f values.yaml -f helm_vars/sandbox/values.yaml `

- suppression du chart déployé avec le nom proxmox-monitoring :

` helm delete proxmox-monitoring `

