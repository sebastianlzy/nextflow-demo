# Prerequisite

1. Java 
2. Nextflow
3. Go

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

# Usage


## Clone repo
```
> git clone https://github.com/sebastianlzy/nextflow-demo
> cd nextflow-demo
```

## Download data
```
> pwd
<path>/nextflow-demo
> goodls -u https://drive.google.com/file/d/1K8oPgVFJZwB_T2nJPc-TmvMGYg7oyU-e/view?usp=sharing
Downloading (bytes)... 5848241
{"Filename": "data.zip", "Type": "file", "MimeType": "application/zip", "FileSize": 5848241}
> unzip data.zip
```

## Run

```
> . ./run.sh
```

# References

