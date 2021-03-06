# Prerequisite

1. Java
2. Nextflow
3. Go
4. AWS configuration and credential setup - https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
5. AWS CDK
6. jq


## 1. Option1 : Install on AWS cloud9

1. Create an [AWS Cloud9](https://ap-southeast-1.console.aws.amazon.com/cloud9/home?region=ap-southeast-1) environment
3. `git clone https://github.com/sebastianlzy/nextflow-demo`
4. `cd nextflow-demo`
5. Setup dependencies, `. ./helper/setup-dependencies-in-cloud9.sh`
6. Create AWS resources in step (1) under Usage
7. In Cloud9, Open Preferences > AWS Settings
   1. Turn off `AWS managed temporary credentials`
8. Open https://ap-southeast-1.console.aws.amazon.com/ec2/v2/home?region=ap-southeast-1#Instances:instanceState=running
9. Select Cloud9 instance
   1. Actions > Security > Modify IAM role
   2. Select `NextflowDemoCDKStack-awsec2nextflowdemoinstanceprofileid-<HashId>`

<details>
<summary>Option 2: Manual installation</summary>

## Clone repo

```
> cd ~
> git clone https://github.com/sebastianlzy/nextflow-demo
```

## Nextflow installation

```
> cd ~
> curl -s https://get.nextflow.io | bash
> export PATH=$PATH:~
```

## Goodls installation

```
> cd ~
> go get -u github.com/tanaikech/goodls
> export PATH=$PATH:~/go/bin/
```

## CDK installation

```
> npm install -g aws-cdk
> cdk --version
```

## jq installation

```
sudo yum install jq
```
</details>

# Usage

## 1. Create AWS resources

Option 1: CDK (preferred)

```
> cd aws-resources-cdk
> npm install
> npm run cdk:deploy
```

<details>
<summary>Option 2: Manual</summary>

#### Create compute environment
1. Open https://ap-southeast-1.console.aws.amazon.com/batch/home?region=ap-southeast-1#compute-environments
2. Click `create`
3. Fill in as follow:
   1. Compute environment name: `ec2-spot-compute-environment`
   2. Provisioning model: `spot`
   3. Leave the rest as default
4. Click `Create compute environment`

#### Create job queues
1. Open https://ap-southeast-1.console.aws.amazon.com/batch/home?region=ap-southeast-1#queues/new
2. Fill in as follow:
   1. Job queue name: `job-queue`
   2. Select a compute environment: `ec2-spot-compute-environment`
3. Click `Create`

#### Create temp bucket

1. Open https://s3.console.aws.amazon.com/s3/bucket/create?region=ap-southeast-1
2. Fill in as follow:
   1. Bucket name: `nextflow-temp-<timestamp>`
3. Click `Create bucket`

### Create output bucket

1. Open https://s3.console.aws.amazon.com/s3/bucket/create?region=ap-southeast-1
2. Fill in as follow:
   1. Bucket name: `nextflow-ouput-<timestamp>`
3. Click `Create bucket`

### Update aws resource

1. `vim aws-output.json`
2. Fill in all the necessary information in the json

```
{
  "NextflowDemoCdkStack": {
    "tempBucketName": "nextflowdemocdkstack-nextflowtemp498b6c2a-c1siyr411tge",
    "iamBatchRoleName": "aws-batch-nextflow-demo-role",
    "outputBucketName": "nextflowdemocdkstack-nextflowoutput8388dea5-1b8tc4n2wo6tn",
    "jobQueueName": "arn:aws:batch:ap-southeast-1:134800022762:job-queue/nextflow-job-queue-demo"
  }
}

```

</details>

## 2. Download data
```
> cd nextflow-demo
> aws s3 cp s3://ee-assets-prod-us-east-1/modules/adea752f4ec54648b489ae4b8a56f243/v1/data.zip data.zip 

download: s3://ee-assets-prod-us-east-1/modules/adea752f4ec54648b489ae4b8a56f243/v1/data.zip to ./data.zip

> unzip data.zip
```

## 3. Copy wgbs data to output bucket
```
> cd nextflow-demo
> aws s3 cp s3://ee-assets-prod-us-east-1/modules/adea752f4ec54648b489ae4b8a56f243/v1/wgbs_genomes.zip wgbs_genomes.zip

download: s3://ee-assets-prod-us-east-1/modules/adea752f4ec54648b489ae4b8a56f243/v1/wgbs_genomes.zip to ./wgbs_genomes.zip

> unzip wgbs_genomes.zip
> aws s3 cp ./wgbs_genomes s3://$(cat aws-outputs.json | jq -r '.NextflowDemoCdkStack.outputBucketName')/wgbs_genomes --recursive
```

## 4. Run pipeline

```
# Run script
> cd nextflow-demo
> . ./run.sh
```

# References



## To configure AWS jobs
1. Edit `vim ./nextflow.config`


## AWS batch jobs
![aws-batch](./readme/aws-batch-jobs.png)

## Output in terminal
![terminal](./readme/final-output.png)