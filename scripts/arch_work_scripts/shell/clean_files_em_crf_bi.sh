#!/bin/bash

DIR1="/srv/data/prod/exchange/data/e-merchant/em_crf_bi/QOSFOD_report/"
RET1="+14400"

DIR2="/srv/data/prod/exchange/data/e-merchant/em_crf_bi/PromoCodes_report/"
RET2="+124"

find $DIR1 -type f -mmin $RET1 -exec rm  {} \;
find $DIR2 -type f -mtime $RET2 -exec rm  {} \;


