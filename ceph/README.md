# Multinode Ceph on Vagrant

This workshop walks users through setting up a 3-node [Ceph](http://ceph.com) cluster and mounting a block device, using a CephFS mount, and storing a blob oject.

It follows the following Ceph user guides:

*   [Preflight checklist](http://ceph.com/docs/master/start/quick-start-preflight/)
*   [Storage cluster quick start](http://ceph.com/docs/master/start/quick-ceph-deploy/)
*   [Block device quick start](http://ceph.com/docs/master/start/quick-rbd/)
*   [Ceph FS quick start](http://ceph.com/docs/master/start/quick-cephfs/)
*   [Install Ceph object gateway](http://ceph.com/docs/master/install/install-ceph-gateway/)
*   [Configuring Ceph object gateway](http://ceph.com/docs/master/radosgw/config/)

## Install prerequisites

Install [Vagrant](http://www.vagrantup.com/downloads.html) and a provider such as [VirtualBox](https://www.virtualbox.org/wiki/Downloads).

We'll also need the [vagrant-cachier](https://github.com/fgrehm/vagrant-cachier) and [vagrant-hostmanager](https://github.com/smdahlen/vagrant-hostmanager) plugins:

```console
$ vagrant plugin install vagrant-cachier
$ vagrant plugin install vagrant-hostmanager
```

## Add your Vagrant key to the SSH agent

Since the admin machine will need the Vagrant SSH key to log into the server machines, we need to add it to our local SSH agent:

On Mac:
```console
$ ssh-add -K ~/.vagrant.d/insecure_private_key
```

On \*nix:
```console
$ ssh-add -k ~/.vagrant.d/insecure_private_key
```

## Start the VMs

This instructs Vagrant to start the VMs and install `ceph-deploy` on the admin machine.

```console
$ vagrant up
```

## Architecture

![](https://docs.ceph.com/docs/master/_images/ditaa-b490c5d9d3bb6984503b59681d08337aff62e992.png)
