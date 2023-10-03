#!/usr/bin/env bash

# read the first parameter given to this file
export IMAGE=$1
docker-compose -f docker-compose.yml up --detach
echo "success"