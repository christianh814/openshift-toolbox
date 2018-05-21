# DaemonSet

Here is an example on how to create a `daemonset` in OpenShift. More info can be found [here](https://docs.openshift.com/container-platform/latest/dev_guide/daemonsets.html)

First create your DS yaml

```
[chernand@chernand entrust-examples]$ cat ds-example.yml 
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: welcome-php
spec:
  template:
    metadata:
      labels:
        app: welcome-php
    spec:
      nodeSelector:
        app: welcome-php
      containers:
        - name: welcome-php
          image: redhatworkshops/welcome-php:latest
          ports:
          - containerPort: 8080
            hostPort: 9999
```

Set privileged containers for the project (you need it for `hostPort`)

```
oc project demo
oc adm policy add-scc-to-user privileged -z default
```

Now create the ds

```
[chernand@chernand entrust-examples]$ oc create  -f ds-example.yml 
daemonset "welcome-php" created

[chernand@chernand entrust-examples]$ oc get ds
NAME          DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR     AGE
welcome-php   1         1         1         1            1           app=welcome-php   5m

```

Now label your node as `app=welcome-php` for the pod to deploy

```
[chernand@chernand entrust-examples]$ oc get ds
NAME          DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR     AGE
welcome-php   0         0         0         0            0           app=welcome-php   6m

[chernand@chernand entrust-examples]$ oc get pods
No resources found.

[chernand@chernand entrust-examples]$ oc label node ip-172-31-25-120.us-west-1.compute.internal app=welcome-php 
node "ip-172-31-25-120.us-west-1.compute.internal" labeled

[chernand@chernand entrust-examples]$ oc get pods
NAME                READY     STATUS              RESTARTS   AGE
welcome-php-dkb2n   0/1       ContainerCreating   0          3s
```

Now you can hit the node directly on the port you specified.

```
[chernand@chernand entrust-examples]$ curl -sI http://ec2-13-56-228-64.us-west-1.compute.amazonaws.com:9999/
HTTP/1.1 200 OK
Date: Wed, 16 May 2018 02:00:40 GMT
Server: Apache/2.4.18 (Red Hat)
Content-Type: text/html; charset=UTF-8
```

Here we went to `ec2-13-56-228-64.us-west-1.compute.amazonaws.com` instead of `ip-172-31-25-120.us-west-1.compute.internal` because I tested this on AWS. On a NONcloud env, you'd just go to the node directly.
