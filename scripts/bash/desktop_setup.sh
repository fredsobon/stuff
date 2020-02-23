#!/bin/bash

sudo apt update -y && sudo apt upgrade -y
sudo apt install -y screen tmux tree tcpdump wireshark nmap lsof strace net-tools gnupg meld xlsx2csv hfsplus hfsprogs hfsutils terminator curl wget tshark keepassx typora  remmina visualvm vim gnome-tweak-tool


sudo mkdir -p /home/boogie/Documents/{learn, own, work, stuff}

wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo apt-get update
sudo apt-get install google-chrome-stable


