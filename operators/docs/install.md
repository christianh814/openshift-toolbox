# Installing The SDK

The first step is to install the SDK. The SDK will help you build and deploy your Operator. The official doc can be found on the [github page](https://github.com/operator-framework/operator-sdk#workflow); and I'd check there first for the latest.

## Prerequisites

There are a few prereqs


* [dep](https://golang.github.io/dep/docs/installation.html) version v0.5.0+.
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [go](https://golang.org/doc/install) version v1.10+.
* [docker](https://docs.docker.com/install/) version 17.03+.
* [oc](https://github.com/openshift/origin/releases) version v3.11+.
* Access to an OpenShift v3.11+ cluster (minishift is fine).
* An account with either [Quay](https://quay.io) or [Docker Hub](https://hub.docker.com)


## Install

To install the SDK (once you have the prereqs in place) is easy

```
mkdir -p $GOPATH/src/github.com/operator-framework
cd $GOPATH/src/github.com/operator-framework
git clone https://github.com/operator-framework/operator-sdk
cd operator-sdk
git checkout master
make dep
make install
```

Verify the installation was done correctly

```
$ operator-sdk --version
operator-sdk version v0.6.0+git
```

## Create an Operator

Now you can visit the [howto](../README.md) to create/install an Operator!
