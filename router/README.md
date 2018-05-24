# Router Notes

The OpenShift router is the ingress point for all traffic destined for services in your OpenShift installation. The router is based on HAProxy, and these notes are in no paticular order.

* [Deploy Router](#deploy-router)

## Deploy Router

Sometimes, you'll need to create a router; although this can be done with the ansible installer. These notes are here for historical purposes.

First create the certificate that will be used for all default SSL connections

```
root@master# CA=/etc/origin/master
root@master# oc adm ca create-server-cert \
--signer-cert=$CA/ca.crt --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
--hostnames='*.cloudapps.example.com' --cert=cloudapps.crt --key=cloudapps.key
root@master# cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem
```

Now create the router

```
root@master# oc adm router \
--default-cert=cloudapps.router.pem --credentials='/etc/origin/master/openshift-router.kubeconfig' \
--selector='region=infra' --images='openshift3/ose-${component}:${version}' --service-account=router
```

