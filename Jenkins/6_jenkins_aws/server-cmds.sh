#!/usr/bin/env bash
set -euo pipefail

# read the first parameter given to this file
export IMAGE="${1:?Image name is required}"

docker-compose -f docker-compose.yml pull
docker-compose -f docker-compose.yml up --detach --remove-orphans
echo "success"
