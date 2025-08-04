#!/bin/bash

DOMAIN=$1
GPU_NOS=$2
JOB_REMAINING_TIME=$3
MESSAGE=$4
RECIPIENT="ankankumarbhunia@gmail.com"

MAIL_BODY="
SLURM Job Details:
Domain Link: https://${DOMAIN}
GPUs: ${GPU_NOS:-None}
Job Remaining Time: ${JOB_REMAINING_TIME:-N/A}
"

echo "${MAIL_BODY}" | mail -s "${MESSAGE}: [Node: $(uname -n)]" "${RECIPIENT}"
