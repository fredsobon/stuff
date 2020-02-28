#!/bin/bash

# update system and retrieve pkgs 
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y screen tmux tree tcpdump wireshark nmap lsof strace net-tools gnupg meld xlsx2csv hfsplus hfsprogs hfsutils terminator curl wget tshark keepassx  remmina visualvm vim gnome-tweak-tool git exfat-fuse exfat-utils

# retrieve repo and create main folders 
cd /home/boogie/Documents/
git clone https://github.com/fredsobon/stuff.git
mkdir -p /home/boogie/Documents/{learn,own,work}

# set chrome browser 
sudo sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y google-chrome-stable

## set up dependencies for zoom app (conf call and video ) :
sudo apt install -y libgl1-mesa-glx libxcb-xtest0

#then dpkg -I zoom pck dl from their website

        
## kube section : ##

# minikube set up - using kvm 

sudo apt-get install y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
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


## shell and prompt tweaks : ##

# zsh install and set up 
sudo apt install -y zsh 
chsh -s $(which zsh)

# oh-my-zsh! setup and prompt config 
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
/usr/bin/zsh
sed -i 's/robbyrussell/agnoster/' /home/boogie/.zshrc

sed -i 's/KUBE_PS1_COLOR_SYMBOL="%{$fg[blue]%}"/KUBE_PS1_COLOR_SYMBOL="%{$fg[green]%}"/' /home/boogie/.oh-my-zsh/plugins/kube-ps1/kube-ps1.plugin.zsh                                         
sed -i 's/KUBE_PS1_COLOR_CONTEXT="%{$fg[green]%}"/KUBE_PS1_COLOR_CONTEXT="%{$fg[yellow]%}"/' /home/boogie/.oh-my-zsh/plugins/kube-ps1/kube-ps1.plugin.zsh                                         
sed -i 's/KUBE_PS1_COLOR_NS="%{$fg[cyan]%}"/KUBE_PS1_COLOR_NS="%{$fg[red]%}"/' /home/boogie/.oh-my-zsh/plugins/kube-ps1/kube-ps1.plugin.zsh                                         
sed  '/KUBE_PS1_COLOR_NS=/ a RPROMPT=`'$(kube_ps1)\'' 
