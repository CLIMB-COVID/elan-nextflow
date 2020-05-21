#!/usr/bin/bash

echo "[ELAN]" `date` " - LETS ROLL"

# https://github.com/conda/conda/issues/7980
eval "$(/cephfs/covid/software/miniconda3/bin/conda shell.bash hook)"
/cephfs/covid/software/miniconda3/bin/conda activate samstudio8

# https://github.com/conda/conda/issues/8186
set -euo pipefail

# Load the environment and credentials
source ~/.ocarina

# Hit up the usual dir
cd /cephfs/covid/software/sam/pre-elan

# Pull down the entire sequencing run manifest
ocarina --quiet --env get sequencing --run-name '*' --tsv --task-wait > latest.tsv
# and link it to the file system
find /cephfs/covid/bham/*/upload -type f -name "*fa*" | grep -v '\.fai$' | python ../elan/bin/ocarina_resolve.py latest.tsv > q 2> t

COUNT_MAJORA=`wc -l latest.tsv | cut -f1 -d' '`
COUNT_ELAN=`wc -l q | cut -f1 -d' '`
COUNT_ELAN_NEW=`grep -c '^1' q`
SITE_COUNTS=`awk '$14=="SANG" {print $14 " ("$13")"; next}; {print $14}' q | sort | uniq -c | sort -nr`
SITE_COUNTS_NEW=`grep '^1' q | awk '$14=="SANG" {print $14 " ("$13")"; next}; {print $14}' | sort | uniq -c | sort -nr`

SITE_MISSING_FILE=`grep 'ORPHAN-SITE' t | awk '{print $6 " " $2}' | sort -k2nr`
FILE_MISSING_META=`grep 'ORPHAN-DIRX' t | awk '$2 > 1 {print $2,$8}' | sort -nr | column -t`

###############################################################################
PRE='{"text":"<!channel>

*COG-UK inbound-distribution pre-pipeline report*
'$COUNT_ELAN_NEW' new sequences this week

***
*Samples with metadata but missing uploaded sequences on CLIMB, by sequencing centre*
Please check your upload directories...'"\`\`\`${SITE_MISSING_FILE}\`\`\`"'

*Uploaded sequences missing metadata by secondary directory*
These directories contain one or more directories with samples that do not have metadata.
Please check you have uploaded all your metadata this week...'"\`\`\`${FILE_MISSING_META}\`\`\`"'
***

*New sequences by centre*'"\`\`\`${SITE_COUNTS_NEW}\`\`\`"'"

***
_The inbound pipeline will be run autonomously at ten minutes past the next hour. Not even Sam will be able to save you._
}'
###############################################################################
POST='{"text":"<!channel>

*COG-UK inbound pipeline ready*
'$COUNT_MAJORA' sample sequencing experiments in Majora
'$COUNT_ELAN_NEW' new sequences this week
'$COUNT_ELAN' sequences matched to Majora metadata

***

*New sequences by centre*'"\`\`\`${SITE_COUNTS_NEW}\`\`\`"'

*Cumulative uploaded sequences by centre*'"\`\`\`${SITE_COUNTS}\`\`\`"'

_Happy Friday!_"}'
###############################################################################

# Announce
curl -X POST -H 'Content-type: application/json' --data "${!1}" "${!2}"
