#!/usr/bin/env nextflow

/*
* This script does the job of analysing pair-end WGBS library prepared by Swiftbio (library methods will impact the trimming parameters)
* 1. run fastQC for raw fastq data 
* 2. split the big fastq file into smaller subsets
* 3. trim adaptors and low quality bases by trim_galore, and then trim extra 18nt for Swiftbio libraries
* 4.1 run fastQC for trimmed reads
* 4.2 map trimmed reads to reference genome by bismark
* 4.3 map trimmed reads to lambda DNA by bismark to estimate bisulfite conversion rate
* 5. merge sub bam files 
* 6. deduplication for merged bam file by bismark
* 7. extract methylation signal and calculate methylation level by bismark
* 8. calculate the coverage (mean depth) by picard
* 9. check the insert size for the library
*/

// 
// input files:  R1, R2 fastq
// softwares/tools required: fastqc, TrimGalore, cutadapt, bismark, samtools, bowtie2, java, python, picard


params.refdir= "./wgbs_genomes"
params.basedir='.'
params.outdir='./wgbs-test/work'
genome_path="${params.refdir}/homo_sapiens/GRCh38"
genome_primary="${params.refdir}/homo_sapiens/GRCh38_primary"
genome_alt="${params.refdir}/homo_sapiens/GRCh38_alt"
lambda_path="${params.refdir}/lambda"
genome_fasta="${params.refdir}/homo_sapiens/GRCh38/hg38.fa"
project_dir = projectDir


// the sample to be analyzed
// https://digitalinsights.qiagen.com/downloads/example-data/

read_pairs_ch = Channel.fromFilePairs("${params.basedir}/data/*_{1,2}.fastq", flat:true, checkIfExists:true)
read_pairs_ch2 = Channel.fromFilePairs("${params.basedir}/data/*_{1,2}.fastq", flat:true, checkIfExists:true)
  

// prepare the genome index
// 1. hg38 primary assembly

// $BISMARK_PATH/bismark_genome_preparation --path_to_aligner $BOWTIE_PATH --bowtie2  --verbose /Volumes/S_BK_ZL/WGBS/wgbs_genomes/homo_sapiens/GRCh38_primary

//2. hg38 alternate contigs
// $BISMARK_PATH/bismark_genome_preparation --path_to_aligner $BOWTIE_PATH --bowtie2 --verbose /Volumes/S_BK_ZL/WGBS/wgbs_genomes/homo_sapiens/GRCh38_alt


/******* STEP1 - FastQC_raw *********
***************************
*/

// ch = Channel.fromPath('./*', type: 'dir')
// ch.view()

process fastqc_raw {

    tag "$sample_id"
    echo true
    
    publishDir "${params.outdir}/fastqc_raw", mode: 'copy', overwrite: true

    input:
    tuple val(sample_id),file(reads_r1),file(reads_r2) from read_pairs_ch


    output:
    tuple val(sample_id),file('*_fastqc.{zip,html}') 
    tuple val(sample_id),file('*_nbases.txt') 

    script:
    """
 #   module load python
    fastqc --quiet ${
    }
    fastqc --quiet ${reads_r2}

 #   python3 docker_config/q30/q30.py ${reads_r1} > ${sample_id}_R1_nbases.txt;
 #   python3 docker_config/q30/q30.py ${reads_r2} > ${sample_id}_R2_nbases.txt

     q30.py ${reads_r1} > ${sample_id}_R1_nbases.txt;
     q30.py ${reads_r2} > ${sample_id}_R2_nbases.txt

    """
}



/******* STEP2 - fastq_split *********
***************************
*/

process fastq_split {

    tag "$sample_id"
    echo true
    
    publishDir "${params.outdir}/wgbs/${sample_id}"

    input:
    tuple val(sample_id), file(reads_r1), file(reads_r2) from read_pairs_ch2

    output:
    tuple val(sample_id), file('*_1.*'), file('*_2.*') into ch_split_fastq

    script:
    """
    cat $reads_r1 | split -l 1000000 - ${sample_id}_1.
    cat $reads_r2 | split -l 1000000 - ${sample_id}_2.
    
    """

}


// regroup the tuple by using two keys
ch_split_fastq.transpose()
        .map {input -> tuple(input[0], input[1].toString().tokenize('.').get(1), input[1], input[2])}
        .groupTuple(by: [0,1])
        .set{ch_fastq_for_trim}


/******* STEP3 - Trim Galore! *********
***************************
*/


process trim_galore {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/wgbs/${sample_id}/trimmed_reads", pattern:"*.trimming_report.txt", mode:'copy', overwrite: true

    input:
    tuple val(sample_id), val(sub_ID),file(split_reads_r1), file(split_reads_r2) from ch_fastq_for_trim

    output:
    tuple val(sample_id),val(sub_ID), file('*_1.*_val_1.fq'), file('*_2.*_val_2.fq') into ch_trimmed_reads_for_alignment,ch_trimmed_reads_for_align_lambda,ch_trimmed_reads_fastQC

    tuple val(sample_id), file("*trimming_report.txt")

    script:
    """

    trim_galore --dont_gzip --clip_R2 18 --three_prime_clip_R1 18 --phred33 --paired ${split_reads_r1} ${split_reads_r2}

    ## remove splitted fastq files
    rm $split_reads_r1 $split_reads_r2

    """
}

//regroup
ch_trimmed_reads_fastQC
	.map {input -> tuple(input[0], input[2], input[3])}
	.groupTuple(by:0)
	.set {ch_trimmed_reads_fastQC2}


/******* STEP4.1 - FastQC for trimmed reads *********
***************************
*/
//
process fastqc_aftertrim {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/fastqc_aftertrim", mode: 'copy', overwrite: true

    input:
    tuple val(sample_id), file(trimmed_reads_r1), file(trimmed_reads_r2) from ch_trimmed_reads_fastQC2

    output:
    tuple val(sample_id), file('*_aftertrim_*nbases.txt'), file('*_fastqc.{zip,html}')


    script:

    """
   ## module load python

    cat ${trimmed_reads_r1} >> ${sample_id}_aftertrim_R1.fq;
    cat ${trimmed_reads_r2} >> ${sample_id}_aftertrim_R2.fq;

  #  python2 /Users/mirmac2103lizhou/mirxes_project/WGBS_AWS/docker_config/q30/q30.py ${sample_id}_aftertrim_R1.fq > ${sample_id}_aftertrim_R1_nbases.txt;
  #  python2 /Users/mirmac2103lizhou/mirxes_project/WGBS_AWS/docker_config/q30/q30.py ${sample_id}_aftertrim_R2.fq > ${sample_id}_aftertrim_R2_nbases.txt;

    q30.py ${sample_id}_aftertrim_R1.fq > ${sample_id}_aftertrim_R1_nbases.txt;
    q30.py ${sample_id}_aftertrim_R2.fq > ${sample_id}_aftertrim_R2_nbases.txt;

    fastqc --quiet ${sample_id}_aftertrim_R1.fq;
    fastqc --quiet ${sample_id}_aftertrim_R2.fq;

    rm ${sample_id}_aftertrim_R1.fq ${sample_id}_aftertrim_R2.fq

    rm ${trimmed_reads_r1} ${trimmed_reads_r2}


    """
}


/******* STEP4.2 - mapping to lambda with Bismark *********
***************************
*/
LAMBDA_PATH=file("${lambda_path}", checkIfExists:true)

process bismark_align_lambda {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/wgbs/$sample_id/bam_files_lambda"

    input:
    tuple val(sample_id), val(sub_ID), file(trimmed_reads_r1),file(trimmed_reads_r2) from ch_trimmed_reads_for_align_lambda
    file LAMBDA_PATH

    output:

    tuple val(sample_id),file("*_bismark_bt2_PE_report.txt")

    script:
    """
    ## --path_to_bowtie2 /usr/local/bin
    bismark --bowtie2 -p 2 --bam --score_min L,0,-0.2 lambda -1 ${trimmed_reads_r1} -2 ${trimmed_reads_r2}

    ## remove the bam files
    rm ${sample_id}*_bismark_bt2_pe.bam


    """
}


/******* STEP4.3 - mapping with Bismark *********
***************************
*/
GENOME_PRIMARY=file("${genome_primary}", checkIfExists:true)
GENOME_ALT=file("${genome_alt}", checkIfExists:true)
//
process bismark_align {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/wgbs/$sample_id/bam_files",  pattern:"*_bismark_bt2_PE_report.txt", mode: "copy", overwrite: true

    input:
    tuple val(sample_id),val(sub_ID), file(trimmed_reads_r1),file(trimmed_reads_r2) from ch_trimmed_reads_for_alignment
    file GENOME_PRIMARY
    file GENOME_ALT

    output:
    tuple val(sample_id),val(sub_ID), file('*_val_1_bismark_bt2_pe.bam'), file('*_val_1.fq_unmapped_reads_1_bismark_bt2_pe.bam') into ch_bismark_bam

//     tuple val(sample_id), file("*_bismark_bt2_PE_report.txt")

    script:
    """
    ## map the overall reads to the hg38 primary assembly
    ## --path_to_bowtie2 /usr/local/bin
    bismark --bowtie2 -p 2 --bam --un --ambiguous --score_min L,0,-0.2 GRCh38_primary -1 ${trimmed_reads_r1} -2 ${trimmed_reads_r2}

    ## map the unmapped reads to hg38 alternate contigs

    bismark --bowtie2 -p 2 --bam --score_min L,0,-0.2 GRCh38_alt -1 ${trimmed_reads_r1}_unmapped_reads_1.fq.gz -2 ${trimmed_reads_r2}_unmapped_reads_2.fq.gz

    ## remove the unmapped reads and ambiguous reads
    rm ${sample_id}*_unmapped_reads_2.fq.gz ${sample_id}*_unmapped_reads_1.fq.gz
    rm ${sample_id}*_ambiguous_reads_2.fq.gz ${sample_id}*_ambiguous_reads_1.fq.gz


    """
}


/******* STEP5 - merge bam files *********
***************************
*/

ch_bismark_bam
        .map{ input -> tuple(input[0], input[2], input[3]) }
        .groupTuple(by:0)
        .set {ch_bismark_bam2}

process merge_bam {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/wgbs/$sample_id/unsortedButMerged_ForBismark_file", mode:"copy", overwrite: true

    input:
    tuple val(sample_id), file(bam_file1), file(bam_file2) from ch_bismark_bam2

    output:
    tuple val(sample_id), file("*_unsorted_merged.bam") into ch_bismark_merged_bam


    script:
    """
    ## module load samtools/1.3

    samtools merge -nf ${sample_id}_unsorted_merged.bam $bam_file1 $bam_file2

    ## remove individual bamfiles
   #  rm $bam_file1 $bam_file2

    """
}


/******* STEP6 - deduplication for merged bam *********
***************************
*/


process deduplication_bam {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/wgbs/$sample_id/unsortedButMerged_ForBismark_file", pattern: "*deduplication_report.txt", mode:"copy", overwrite: true

    input:
    tuple val(sample_id), path(merged_bam) from ch_bismark_merged_bam

    output:
    tuple val(sample_id), file('*unsorted_merged.deduplicated.bam') into ch_deduplicated_bam_for_methylextract, ch_deduplicated_bam_for_sort

    tuple val(sample_id), file("*_unsorted_merged.deduplication_report.txt")

    script:
    """
    deduplicate_bismark -p --bam $merged_bam

    ## remove the unsorted undeduplicated bam
    rm $merged_bam

    """
}

/******* STEP7 - methylation extraction *********
***************************
*/


filelist_genome_path=file("$genome_path", checkIfExists:true)

process methyl_extract {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/wgbs/$sample_id/unsortedButMerged_ForBismark_file/methylation_extraction", mode:"copy", overwrite: true

    input:
    tuple val(sample_id), path(merged_deduplicated_bam) from ch_deduplicated_bam_for_methylextract
    file filelist_genome_path

    output:
    file "*"


    script:
    """

    bismark_methylation_extractor -p --multicore 4 --gzip --no_overlap --comprehensive --merge_non_CpG --cutoff 1 --buffer_size 40G --zero_based --cytosine_report --genome_folder GRCh38 $merged_deduplicated_bam


    """

}


/******* STEP8 - sort bam *********
***************************
*/

process sort_bam {

    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/coverage_files_picard", mode:"copy", overwrite: true

    input:
    tuple val(sample_id), path(merged_deduplicated_bam) from ch_deduplicated_bam_for_sort


    output:
    tuple val(sample_id), file('*_sorted_deduplicated.bam') into ch_bismark_sorted_deduplicated_bam1, ch_bismark_sorted_deduplicated_bam2

    script:
    """
   ## 	  module load java
   ## 	  module load samtools/1.3

    	  samtools sort -@ 12 -m 4G -o ${sample_id}_sorted_deduplicated.bam $merged_deduplicated_bam

    """

}

/******* STEP9 - coverage analysis *********
***************************
*/

GENOME_FASTA=file("${genome_fasta}", checkIfExists:true)

process coverage {


    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/coverage_files_picard", mode:"copy", overwrite: true

    input:
    tuple val(sample_id), path(sorted_deduplicated_bam) from ch_bismark_sorted_deduplicated_bam1
    file GENOME_FASTA

    output:

    tuple val(sample_id),file("*_coverage_picard.txt")

    script:
    """
   ## 	  module load java
   ## 	  module load samtools/1.3

	picard CollectWgsMetrics REFERENCE_SEQUENCE=hg38.fa \
	    MINIMUM_MAPPING_QUALITY=0 \
		INPUT=$sorted_deduplicated_bam \
		OUTPUT=${sample_id}_coverage_picard.txt


    """

}



/******* STEP10 - insert size analysis *********
***************************
*/


process insert_size {


    tag "$sample_id"
    echo true

    publishDir "${params.outdir}/insert_size_files", mode:"copy", overwrite: true

    input:
    tuple val(sample_id), path(sorted_deduplicated_bam) from ch_bismark_sorted_deduplicated_bam2

    output:

    tuple val(sample_id),file("*_insert_size_metrics.txt")

    script:
    """
  ##  module load java

    picard CollectInsertSizeMetrics \
        I=$sorted_deduplicated_bam \
        O=${sample_id}_insert_size_metrics.txt \
        H=${sample_id}_insert_size_histogram.pdf \
        INCLUDE_DUPLICATES=false \
        ASSUME_SORTED=true

    """

}



