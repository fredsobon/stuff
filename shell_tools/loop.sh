#!/bin/bash
# help to logg on each virtual machine and parse all vm config with selected extract : name / memory and vcpu. Output in scrren and file .

for i in $(seq -w 1 10);
	do ssh virt$ 'for vm in $(ls -1 /etc/xen/vm/* ) ; do cat $vm |grep -Ei "name|memory|vcpus";done'
	done | tee -a virt_lst
