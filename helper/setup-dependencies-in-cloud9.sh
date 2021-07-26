#!/bin/bash

echo "Installing Nextflow"
cd ~
curl -s https://get.nextflow.io | bash
echo "Nextflow installed"

echo "Installing Goodls"
cd ~
wget https://github.com/tanaikech/goodls/releases/download/v1.2.7/goodls_linux_amd64
mv goodls_linux_amd64 goodls
chmod 755 goodls
echo "Goodls installed"

echo "Installing CDK"
npm install -g aws-cdk
cdk --version
echo "CDK installed"

echo "installing jq"
sudo yum install -y jq
echo "jq installed"

echo "resize instance to 100GB"
. ~/environment/nextflow-demo/helper/resize-ebs.sh 100
echo "resized instance to 100GB"

export PATH=$PATH:~