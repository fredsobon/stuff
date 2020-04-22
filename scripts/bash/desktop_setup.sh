#!/bin/bash

sudo apt update -y && sudo apt upgrade -y
sudo apt install -y screen tmux tree tcpdump wireshark nmap lsof strace net-tools gnupg meld xlsx2csv hfsplus hfsprogs hfsutils terminator curl wget tshark keepassx  remmina visualvm vim gnome-tweak-toola git docker.io

sudo addgroup boogie docker

sudo mkdir -p /home/boogie/Documents/{learn,own,work,lab}

sudo sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo apt-get update
sudo apt-get install google-chrome-stable

## set up dependencies for zoom app (conf call and video ) :
sudo apt install libgl1-mesa-glx libxcb-xtest0
#then dpkg -I zoom pck dl from their website

        
## kube section :


# minikube set up - using kvm 

sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube
sudo cp minikube /usr/local/bin && rm minikube
minikube config set vm-driver kvm2

# kubectl binary : 

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# k9s :
curl -LO https://github.com/derailed/k9s/releases/download/v0.16.1/k9s_Linux_x86_64.tar.gz
tar -xzvf k9s_Linux_x86_64.tar.gz
sudo mv k9s /usr/local/bin


# krew set up : kube plugin manager :

(
  set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v0.3.4/krew.{tar.gz,yaml}" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" &&
  "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz &&
  "$KREW" update
)

# set up ctx and ns plugins :
kubectl krew install ctx
kubectl krew install ns
