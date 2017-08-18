#!/bin/bash

# Install Golang 1.8
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get update
sudo apt-get install golang-go

# Add GOPATH
echo -e 'export GOPATH=~/go\nexport PATH=$PATH:~/go/bin' >> ~/.bashrc
source ~/.bashrc

# Install Terraform
go get github.com/hashicorp/terraform
go get github.com/isaacsgi/terraform-provider-azurerm
mv ~/go/src/github.com/isaacsgi ~/go/src/github.com/terraform-providers

# Build Terraform providers
cd ~/go/src/github.com/terraform-providers/terraform-provider-azurerm
make

# Build Terraform
cd ~/go/src/github.com/hashicorp/terraform
make fmt && make quickdev