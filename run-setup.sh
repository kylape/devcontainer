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
scp -i "$keyfile" "$tarfile" "fedora@$hostname:/tmp/setup.tar"
ssh -i "$keyfile" fedora@$hostname sh -c "cd /tmp; tar xvf /tmp/setup.tar; ./setup.sh -s"

echo "Host devcontainer
    HostName localhost
    Port 2222
    User root
    ProxyJump ec2host
    DynamicForward 8080
    RemoteCommand /usr/bin/zsh
    RequestTTY yes
    LogLevel QUIET

Host ec2host
    HostName $hostname
    User fedora
    Port 22
    IdentityFile $keyfile"
