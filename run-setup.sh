#!/bin/bash

if [[ "$1" == "" ]]; then
    echo "Provide key file"
    exit 1
fi

if [[ "$2" == "" ]]; then
    echo "Provide hostname"
    exit 1
fi

keyfile=$1
hostname=$2

tarfile=$(mktemp)
tar cvf "$tarfile" host/ resources/ setup.sh
scp -i "$keyfile" "$tarfile" "ec2host:/tmp/setup.tar"
ssh -i "$keyfile" ec2host sh -c "cd /tmp; tar xvf /tmp/setup.tar; ./setup.sh -sm"

