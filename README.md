# ImputingWithSangerService

This repository provides a personal pipeline of preparatory steps taken to upload and impute PLINK files using the **[Sanger Imputation Service](https://imputation.sanger.ac.uk/)**. It includes: 

1. Steps and tools used to liftover genotype files on older genome builds (pre GRCh37).

2. Steps and tools used to identify and flip all alleles to the forward strand and remove any ambigious SNPs.

3. Conversion of plink files to VCF format, ensuring the correct reference allele.

4. Post-imputation reconstruction of files.

Scripts currently suboptimal whilst learning, but do the job. These will be revised to be more automated as continue to learn.

Assumes ch1-22

---

## Software and Files Required

* **[PLINK 2.0 software](https://www.cog-genomics.org/plink/2.0/)**
* PLINK binary files (.bed/.bim/.fam) which have undergone pre-imputation QC (*see [JoniColeman/gwas_scripts](https://github.com/JoniColeman/gwas_scripts)* for steps on this).
* **[Python 3](https://www.python.org/downloads/)** and **[Conda for Python](https://docs.conda.io/projects/conda/en/latest/user-guide/install/macos.html)**
* **pip** for Python. *Can be installed using the cURL command: `curl https://bootstrap.pypa.io/get-pip.py | python`. Can first check whether already installed by typing `pip --version`*
* **snpflip** Python package. Install using pip: `pip install snpflip` *(package developed by [biocore-ntnu](https://github.com/biocore-ntnu/snpflip))*
* A copy of the 1000 genomes (build GRCh37) fasta file. *Can be downloaded from the 1kg genomes **[ftp folder](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/)**. File for download = **"human_glk_v37.fasta.gz"***. 

Access to a Mac or Linux OS command line is required throughout (with exception of Globus Connect).

---

### Setting Up Globus Connect


* To transfer files via Sanger's Imputation Service, a **[Globus Connect Personal account](https://www.globus.org/globus-connect)** must be set up and installed on local desktop. 

Installation instructions can be found [here](https://www.globus.org/globus-connect-personal)

---

### Specify paths to files

```
plink=/path/to/plink
binary=/path/to/[prefix of PLINK binary file name - omitting .bed/.bim/.fam]
scripts=/path/to/imputation/scripts/directory
snpflip=/path/to/snpflip/directory
fasta=/path/to/fasta/file
```

---

## Lifting Over Genotype Files

The Sanger Imputation Service requires genotype files to be aligned to genome build GRCh37, so any older build versions will need to be lifted over prior to upload. For files already aligned to GRCh37, this section can be skipped.

*Note: This section assumes knowledge of the genotype chip that PLINK files were typed on. This information will need to be sourced before proceeding with the outlined.

* Locate and download the source strand for your specific genotype chip from the **[Wrayner tools](https://www.well.ox.ac.uk/~wrayner/strand/sourceStrand/index.html)** website.
   
   
   * **Example:** If genotype files typed on the Illumina Human610-Quad BeadChip, I would locate this chip from the list and download the build 37 zip file, as indicated by "b37":
  
  Human610-Quadv1_**B-b37**.Source.strand.zip


* Unzip source strand file and align .bim b36 SNPs to new b37 source strand, using update_build.sh script developed by [Mike Wrayner](https://www.well.ox.ac.uk/~wrayner/tools/) (in repo). *Note: last arg provided = the output name for binary file:*

```
bash $scripts/update_build.sh $binary [chip_name]-b37.Source.strand $binary_b37 
```

----

## Prepare PLINK files for Imputation

* Use `$snpflip` and `$fasta` to generate files confirming any reverse strand SNPs which require flipping and ambiguous SNPs requiring removal:  

```
$snpflip -b $binary_b37.bim -f $fasta -o $binary
```

#### Inputs 
(*see also [biocore-ntnu](https://github.com/biocore-ntnu/snpflip)*)

| Parameter  | Description   | 
| :----------| :---------------------------------| 
| -b         | .bim file containing your SNPs    | 
| -f         | 1000 genomes fasta file to use as reference to determine direction    | 
| -o         | prefix for output files           |      
| -h         | help                              | 


#### Outputs

| File            | Description   | 
| :---------------| :----------------------------| 
| .reverse        | All SNPs from .bim file identified as being aligned to reverse strand   | 
| .ambiguous       | All SNPs from .bim file unable to be identied as forward or reverse    | 
| .annotated_bim  | A 9 column file confirming: Chromosome, base_pair, RSID, genetic distance, A1(as is), A2(as is), reference allele (aligned to 1kg), reference_rev (reverse reference aligned to 1kg), strand (confirmation of whether forward or reverse).       |      


* Use .reverse to flip alleles in .bim file and .ambiguous to remove ambiguous SNPs:

``` 
$plink --bfile $binary_b37 --flip $binary.reverse --exclude $binary.ambiguous --make-bed --out $binary_b37_flipped
```

* Generate ref allele file using .annotated_bim

```
cut -f 3,7 $binary.annotated_bim | sed 1d > refallele.txt
```

* Generate VCF file (required file format for Sanger Service), keeping ref allele order using refallelle.txt file:

```
$plink --bfile $binary_b37_flipped --a2-allele refallele.txt --recode vcf --out $binary_b37_flipped_sanger
```

* `gzip` VCF file.

---

## Register Imputation Job

* When files are gzipped and ready to tranfer to Sanger, register a new imputation job from the site **[homepage](https://imputation.sanger.ac.uk/)**

There will then be a requirement to label job and select imputation pipeline. As genotype files have been aligned using 1000 genomes, below selection is preferable: 

#### Inputs

| Field           | Selection   | 
| :---------------| :------------------------------------------| 
| Job Label       | An identifiable name to reference your job   | 
| Reference Panel | 1000 Genomes Phase 3    | 
| Pipeline | pre-phase with EAGLE2 and impute    | 


* Once submitted, Sanger will send a mail through to the email address provided when registering imputation job. This will take you through to the globus file manager. **Ensure personal globus connect account is active on desktop otherwise you will be unable to connect to your files**. 

   Further instructions on transfering file(s) via globus can be found **[here](https://imputation.sanger.ac.uk/?instructions=1).**
   
---

## Post Imputation Reconstruction of Files

Sanger will send an email once the imputation pipeline has been completed. This is followed by an email from global providing a link to download imputed files.

**Files are returned in VCF format and split per-chromosome**

Each VCF will need to be individually transferred back into a local directory before post imputation reconstruction can occur.

### Reconstructing Files

* Gunzip files

```
gunzip *.vcf
```

* Extract SNPs with INFO scores >=0.7 from each VCF file and store in INFOextraction file:

```
bash $scripts/extract_info.sh
```

* Cat INFO files together:

```
cat *.INFOextraction > Merged_INFO_File
```

* Remove un-named, rare variants from files also to create a final SNP includes file:
```
bash $scripts/remove_unnamed.sh
```

* Recode each VCF back into PLINK format
```
for i in *.vcf; do
$plink --vcf $i --alow-no-sex --make-bed --out $i; done
```

* Extract SNPs from final SNP includes file (no unnamed and INFO =>0.7):
```
bash $scripts/extract_final_snps.sh
```

* Merge chromosomes back together
```
$plink --allow-no-sex --bfile 1.vcf --merge-list $scripts/per_chrm_merge --make-bed --out $binary_imputed
```

* Move all VCF files into seperate dircetory and archive
```
mkdir vcfs
mv *.vcf.* vcfs
tar -zcvf vcf_archive.tar.gz vcfs
```

* Remove post-imputation low freq SNPs and create final cleaned file:

```
plink --bfile $binary_imputed --geno 0.01 --maf 0.01 --hwe 0.0001 --make-bed --out $binary_imputed_CLEAN
```

*Note: sex and affection fields may have been removed from .fam files during imputation. If this is the case, these will need to be added back in using --pheno and --update-sex flags within PLINK.

```
Example:
$plink --bfile $binary_imputed_CLEAN --phone /path/to/casecontrol/file --update-sex /path/to/sex/file --make-bed --out $$binary_imputed_updatedpheno_FINAL
```

---

jodie.lord@kcl.ac.uk

---

#END
