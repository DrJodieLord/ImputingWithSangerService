##JodieLord

#!/bin/bash

awk '{if($1!="."){print}}' Merged_INFO_File | cut -d " " -f 1 > FINAL_SNP_INCLUDES
