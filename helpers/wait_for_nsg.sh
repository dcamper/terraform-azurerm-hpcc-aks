#!/usr/bin/env bash

set -e

SUB=$1
RSG=$2

RES0=""
RES=""

while [ true ]
do
    RES0=`az graph query -q "Resources | project Name=name, SubscriptionID=subscriptionId, ResourceGroupName=resourceGroup, ResourceType=type | where SubscriptionID =~ '${SUB}' and ResourceGroupName =~ '${RSG}' and ResourceType =~ 'microsoft.network/networksecuritygroups'" --query "data[0].Name" -o tsv`
    RES=${RES0##( )}
    if [ -n "${RES}" ]; then
        break;
    fi
    sleep 5
done

echo "{\"nsg\": \"${RES}\"}"
