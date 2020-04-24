#! /bin/bash

data=$1

grep -iE $data /etc/hosts
