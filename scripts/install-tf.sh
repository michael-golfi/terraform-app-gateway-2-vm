#!/bin/bash

# Install Golang 1.8
echo "Installing go"
sudo add-apt-repository -y ppa:longsleep/golang-backports
sudo apt-get update -y
sudo apt-get install -y golang-go

# Add GOPATH
echo "Add GOPATH"
export GOPATH=~/go
export PATH=$PATH:~/go/bin

# Install Terraform
echo "go get Terraform"
go get github.com/hashicorp/terraform
go get github.com/isaacsgi/terraform-provider-azurerm
mv ~/go/src/github.com/isaacsgi ~/go/src/github.com/terraform-providers

# Build Terraform providers
echo "Making Terraform Azure Provider"
cd ~/go/src/github.com/terraform-providers/terraform-provider-azurerm
make

# Build Terraform
echo "Making Terraform"
cd ~/go/src/github.com/hashicorp/terraform
make fmt && make quickdev

echo "To use Terraform"
echo 'export PATH=$PATH:~/go/bin'