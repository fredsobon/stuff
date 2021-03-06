#!/bin/bash

#### main conf : 

# update system and retrieve pkgs 
sudo apt update -y && sudo apt upgrade -y

# add repos for requested apps : chrome / podman - buildah
sudo sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_19.10/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_19.10/Release.key -O- | sudo apt-key add -

# create folders 
mkdir -p /home/boogie/Documents/{learn,own,work,lab}

# misc packets 
sudo apt install -y screen tmux tree tcpdump wireshark nmap lsof strace net-tools gnupg meld xlsx2csv hfsplus hfsprogs hfsutils terminator curl wget tshark keepassx  remmina visualvm vim gnome-tweak-tool git exfat-fuse exfat-utils fonts-powerline vlc openssh-server python3-pip snapd qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager locate mtr zsh docker.io google-chrome-stable podman buildah 

# adjust perm for some apps : 
sudo addgroup boogie docker
sudo usermod -a -G libvirt $(whoami)

## set up dependencies for zoom app (conf call and video ) :
sudo apt install libgl1-mesa-glx libxcb-xtest0
        
## kube section : ##

# minikube set up - using kvm 
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

# helm section - binary and plugins :
(
set -x ; cd "$(mktemp -d)" &&
curl -fsSLO "https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz" && tar -xzvf helm-v3.1.1-linux-amd64.tar.gz ; sudo cp linux-amd64/helm /usr/local/bin/
)

helm plugin install https://github.com/futuresimple/helm-secrets
helm plugin install https://github.com/databus23/helm-diff --version master
helm plugin install https://github.com/chartmuseum/helm-push

# stern : logger for kube :
curl -fsSLO "https://github.com/wercker/stern/releases/download/1.11.0/stern_linux_amd64" && sudo mv stern_linux_amd64 /usr/local/bin/stern && sudo chmod +x /usr/local/bin/stern

## shell and prompt tweaks : ##

chsh -s $(which zsh)
# zsh install and set up 

# oh-my-zsh! setup and prompt config 
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
(
sed -i 's/robbyrussell/agnoster/' /home/boogie/.zshrc
sed -i 's/plugins=(git)/plugins=(git kubectl kube-ps1 docker go golang python colorize)' /home/boogie/.zshrc

sed -i 's/KUBE_PS1_COLOR_SYMBOL="%{$fg[blue]%}"/KUBE_PS1_COLOR_SYMBOL="%{$fg[green]%}"/' /home/boogie/.oh-my-zsh/plugins/kube-ps1/kube-ps1.plugin.zsh                                         
sed -i 's/KUBE_PS1_COLOR_CONTEXT="%{$fg[green]%}"/KUBE_PS1_COLOR_CONTEXT="%{$fg[yellow]%}"/' /home/boogie/.oh-my-zsh/plugins/kube-ps1/kube-ps1.plugin.zsh                                         
sed -i 's/KUBE_PS1_COLOR_NS="%{$fg[cyan]%}"/KUBE_PS1_COLOR_NS="%{$fg[red]%}"/' /home/boogie/.oh-my-zsh/plugins/kube-ps1/kube-ps1.plugin.zsh                                         
sed -i  '/KUBE_PS1_COLOR_NS=/ a RPROMPT='$(kube_ps1)'' /home/boogie/.oh-my-zsh/plugins/kube-ps1/kube-ps1.plugin.zsh
)


# to do : set up zoom

# set up go :
#on download la derniere version dispo
#on décompresse l'archive dans le rep /usr/local par ex
#sudo tar -C /usr/local -xzvf go1.14.2.linux-amd64.tar.gz
#un check de l'install :
#ls /usr/local/go
#on va rajouter le binaire dans notre path 
#vi ~/.profile ou ~/.bashrc ou ~.zshrc ...
#..
#export PATH=$PATH:/usr/local/go/bin
#go version 
#go version go1.14.2 linux/amd64
#creation du gopath qui servira a heberger les projets :
#mkdir go && mkdir go/src
## Go path :
#export GOPATH=$HOME/Documents/go
#on utilise visualstudiocode
#ex :
#https://code.visualstudio.com/docs/?dv=linux64_deb
#sudo dpkg -i code_1.44.0-1586345345_amd64.deb
#
##
