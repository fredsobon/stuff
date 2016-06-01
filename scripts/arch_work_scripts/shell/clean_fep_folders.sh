#!/bin/bash
# Maxime Guillet - Tue, 02 Sep 2014 15:35:19 +0200

PREFIX=/mnt/share/dataexchange/data/pixmania/fep/

find $PREFIX/bo_fv_sales_collection_online/{OK,KO} $PREFIX/customer_master_data/{OK,KO} -type f -mtime +2 -delete
