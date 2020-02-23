#!/bin/bash

sudo apt update -y && sudo apt upgrade -y
sudo apt install -y screen tmux tree tcpdump wireshark nmap lsof strace net-tools gnupg meld xlsx2csv hfsplus hfsprogs hfsutils terminator curl wget tshark keepassx  remmina visualvm vim gnome-tweak-toola git


sudo mkdir -p /home/boogie/Documents/{learn,own,work}

sudo sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo apt-get update
sudo apt-get install google-chrome-stable

## set up dependencies for zoom app (conf call and video ) :
sudo apt install libgl1-mesa-glx libxcb-xtest0
then dpkg -I zoom pck dl from their website

        
