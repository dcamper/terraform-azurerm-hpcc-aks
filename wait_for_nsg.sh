#!/usr/bin/env bash

set -e

SUB=$1
RSG=$2

RES0=""
RES=""

while [ true ]
do
    RES0=`az network nsg list --subscription "${SUB}" --resource-group "${RSG}" --query "[].{name:name}" -o tsv`
    RES=${RES0##( )}
    if [ -n "${RES}" ]; then
        break;
    fi
    sleep 5
done

echo "{\"nsg\": \"${RES}\"}"
