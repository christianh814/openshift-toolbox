# Router Notes

The OpenShift router is the ingress point for all traffic destined for services in your OpenShift installation. The router is based on HAProxy, and these notes are in no paticular order.

* [Deploy Router](#deploy-router)
* [Health Checks](#health-checks)
* [Router Settings](#router-settings)
* [Node Port](#node-port)
* [Ingress](#ingress)

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

## Health Checks

To check the health of the router endpoint 

```
curl http://infra1.example.com:1936/healthz
```

To check the health of the API service; check the master server endpoint

```
curl --cacert /etc/origin/master/master.server.crt https://master1.example.com:8443/healthz
```
## Router Settings

By default the route does leastconn with sticky sessions. Annotate the application route with roundrobbin/cookies to disable it.

```
oc annotate route/myapp haproxy.router.openshift.io/balance=roundrobin
oc annotate route/myapp haproxy.router.openshift.io/disable_cookies=true
```

To do sticky set it to..

```
oc annotate route/myapp haproxy.router.openshift.io/balance=source
```

## Node Port

A `nodePort` allows you to connect to a pod directly to one of the nodes (ANY node in the cluster) on a specific port (thus bypassing the router). This is useful if you want to expose a database outside of the cluster.

To create nodeport; first setup the file

```
$ cat nodeport-ssh.yaml 
apiVersion: v1
kind: Service
metadata:
  name: ssh-fedora
  labels:
    vm: fedora
spec:
  type: NodePort
  ports:
    - port: 22
      nodePort: 31122
      name: ssh
  selector:
    vm: fedora
```

Make sure you label either the pod/deploymentconfig or whatever you're trying to reach

```
oc label vm vm-fedora vm=fedora
oc label pod virt-launcher-vm-fedora-vt74t vm=fedora
```

Now you can create the definition

```
oc create -f nodeport-ssh.yaml
```

In this case; you'll be able connect into port `31122` (on to ANY server in the cluster) and it will foward it to port `22` on the pod that matches the label.

# Ingress

Ingress specific notes

## IngressClass

QnD (more to come). When deploying another Ingress controller (say NGINX) on OpenShift.

* Make sure it deploys on a non router node (port conflicts)
* Create an Ingress Object
* Ingress object must have `.spec.ingressClassName`


Example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-static-ingress
  namespace: testing
spec:
  ingressClassName: nginx
  rules:
  - host: 127.0.0.1.nip.io
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: myservice
            port:
              number: 8080
```

You may also need `kubernetes.io/ingress.class: "nginx"` (for example) until controllers are updated to support ingress classes. [MORE INFO](https://kubernetes.io/docs/concepts/services-networking/ingress/)
