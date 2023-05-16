#!/bin/bash

# Modify the bucket name
export S3_OUTPUT_BUCKET=s3://$(cat aws-outputs.json | jq -r '.NextflowDemoCdkStack.outputBucketName')
export S3_TEMP_BUCKET=s3://$(cat aws-outputs.json | jq -r '.NextflowDemoCdkStack.tempBucketName')
export QUEUE_NAME=s3://$(cat aws-outputs.json | jq -r '.NextflowDemoCdkStack.jobQueueName')

# Run pipeline locally
# source venv/bin/activate
# RUN_NEXTFLOW_PIPELINE=nextflow run main.nf -c nextflow.config -profile local --outdir=s3://nextflow-leesebas/output

# Run pipeline on container
# RUN_NEXTFLOW_PIPELINE=nextflow run main.nf  -profile docker --outdir=s3://nextflow-leesebas/output

# Run pipeline on AWS
timestamp()
{
 date +"%Y-%m-%d-%H:%M:%S"
}

./nextflow -log /Users/leesebas/workspace/nextflow-demo/log/nextflow.log run tutorial.nf -bucket-dir $S3_TEMP_BUCKET -c nextflow.config -profile awscloud
#QUEUE_NAME=$QUEUE_NAME ./nextflow -log /Users/leesebas/workspace/nextflow-demo/log/nextflow.log run tutorial.nf -bucket-dir $S3_TEMP_BUCKET --outdir=$S3_OUTPUT_BUCKET/output-$(timestamp) -c nextflow.config
#RUN_NEXTFLOW_PIPELINE="nextflow run main.nf -profile aws -bucket-dir $S3_TEMP_BUCKET --outdir=$S3_OUTPUT_BUCKET/output-$(timestamp) --refdir=$S3_OUTPUT_BUCKET/wgbs_genomes"
# RUN_NEXTFLOW_PIPELINE="nextflow run main.nf -profile aws -bucket-dir $S3_TEMP_BUCKET --outdir=$S3_OUPUT_BUCKET-$(timestamp) --refdir=$S3_OUPUT_BUCKET/wgbs_genomes" -resume

echo $RUN_NEXTFLOW_PIPELINE
eval $RUN_NEXTFLOW_PIPELINE

