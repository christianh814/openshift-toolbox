# Operators

An [Operator](https://coreos.com/operators/) is a method of packaging, deploying and managing a Kubernetes application. A Kubernetes application is an application that is both deployed on Kubernetes and managed using the Kubernetes APIs and kubectl tooling.

To be able to make the most of Kubernetes, you need a set of cohesive APIs to extend in order to service and manage your applications that run on Kubernetes. You can think of Operators as the runtime that manages this type of application on Kubernetes. You can find more info [here](https://coreos.com/blog/introducing-operator-framework)

You can think of an Operator as a Kubernetes application operation manager system.

An [Operator Framework](https://coreos.com/blog/introducing-operator-framework) was developed to make it easier to create an maintain them. Right now helm, go, and ansible are supported. In this doc I'm going to go over how to create an ansible one.


## Ansible Operators

THIS SECTION IS UNDER CONSTUCTION!

Since the release of v1 of the OperatorSDK, I'll need to make updates. For now, look at [the official docs](https://sdk.operatorframework.io/docs/building-operators/ansible/tutorial/)...they're pretty good.
