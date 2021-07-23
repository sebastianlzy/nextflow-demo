#!/bin/bash


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

RUN_NEXTFLOW_PIPELINE="nextflow run main.nf -profile aws -bucket-dir s3://nextflow-temp --outdir=s3://nextflow-leesebas/output-$(timestamp) --refdir=s3://nextflow-leesebas/wgbs_genomes"
# RUN_NEXTFLOW_PIPELINE="nextflow run main.nf -profile aws -bucket-dir s3://nextflow-temp --outdir=s3://nextflow-leesebas/output --refdir=s3://nextflow-leesebas/wgbs_genomes -resume"

echo $RUN_NEXTFLOW_PIPELINE
eval $RUN_NEXTFLOW_PIPELINE

