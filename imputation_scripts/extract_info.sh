##Produced by Jodie Lord

#!/bin/bash


##Clunky code to extract INFO>0.7. Need to refine, but works. 

##Gunzip files

gunzip *.vcf

##Extract INFO =>0.7 

for i in *.vcf; do
tail -n +105 $i | awk '{print $3, $8}' | sed -e 1d | cut -f 1-5 -d ";" --output-delimiter=" " | awk '{if($2=="TYPED") print $1,$3,$4,$5,$6; else if ($2!="TYPED") print $1, $2, $3, $4, $5}' | cut -f 1,5 -d "=" --output-delimiter=" " | awk '{if($3 >=0.7){print $1, $3}}' > $i.INFOextraction; done


