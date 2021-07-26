#!/bin/bash

echo "Installing Nextflow"
cd ~
curl -s https://get.nextflow.io | bash
export PATH=$PATH:~

echo "Installing Goodls"
cd ~
go get -u github.com/tanaikech/goodls
export PATH=$PATH:~/go/bin/

echo "Installing CDK"
npm install -g aws-cdk
cdk --version

echo "installing jq"
sudo yum install jq