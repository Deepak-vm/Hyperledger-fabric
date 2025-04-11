#!/bin/bash

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

function errorln() {
  echo -e "\033[0;31m$1\033[0m"
}

# Install Go 1.20 (recommended for Fabric 2.x)
println "Installing Go language..."
cd ~
wget https://go.dev/dl/go1.20.12.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.20.12.linux-amd64.tar.gz
rm go1.20.12.linux-amd64.tar.gz

# Set up Go environment variables
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
echo 'export GOPATH=$HOME/go' >> ~/.profile
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.profile
source ~/.profile

# Verify Go installation
go version

println "Go installation completed!"