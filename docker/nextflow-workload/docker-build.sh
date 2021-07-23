# AWS ECR
#export RNASEQ_REPO_URI=134800022762.dkr.ecr.ap-southeast-1.amazonaws.com/nextflow-rna-seq
#export IMG_TAG=2021-07-13.1

# Docker
#export RNASEQ_REPO_URI=sebastian987/nf-wgbs
#export IMG_TAG=v0.0.1

# Build container
#docker build -t $RNASEQ_REPO_URI:${IMG_TAG} .

# Push container
#docker push $RNASEQ_REPO_URI:${IMG_TAG}

# SSH into container
# docker run -it 134800022762.dkr.ecr.ap-southeast-1.amazonaws.com/nextflow-rna-seq:2021-07-13.1 'bin/bash'

