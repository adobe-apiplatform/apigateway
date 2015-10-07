#!/bin/bash

set -o nounset
set -o errexit

docker login --username="${CONCUR_QUAY_ROBOT_USERNAME}" --password="${CONCUR_QUAY_ROBOT_PWD}" --email="${CONCUR_QUAY_ROBOT_EMAIL}" quay.io
