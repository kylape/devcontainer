# Host Move In Scripts

This directory is intended to provide a set of move-in scripts for an empty VM
such that I can log in to the devcontainer directly from my workstation after
this script completes.  Current assumptions:

* EC2 instance
* VM will be Fedora
* Supporting ARM and AMD64, though mostly working on ARM
* Instance type is currently `r6g.4xlarge`

A few design choices:

* KinD cluster
* PVCs will be provisioned on a tmpfs mount, making them memory mapped
* Deploy a container registry to be available for use by KinD
* Deploy devcontainer into the KinD cluster
* Expose SSH server in devcontainer using `NodePort`
* SSH config to use host as a "jump host" to the devcontainer
