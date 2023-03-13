#!/usr/bin/env bash

set -e

IP=$(kubectl get svc --field-selector metadata.name=eclwatch | awk 'NR==2 {print $4}')

echo "{\"ip\": \"${IP}\"}"
