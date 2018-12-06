# NetworkPolicy QnD

These are "quick and dirty" notes. Hacked together by [this blog](https://blog.openshift.com/network-policy-objects-action/) and this [COP github page](https://github.com/redhat-cop/openshift-toolkit/tree/master/networkpolicy)


## Admin Tasks

It's important to make sure the default namespace is labeled properly. This is an admin task

```
oc login -u system:admin
oc label namespace default name=default
oc label namespace default name=kube-service-catalog
```


## Default Deny

**NOTE** Before you start, make sure you're in the right project!

```
oc login -u developer
oc project myproject
```

You need to deny ALL traffic coming into your namespace.


```
oc create -f default-deny.yaml
```

^ This essentially "breaks" your project as ALL traffic (wanted and unwanted alike) is blocked.

## Allow Router/K8S

Next, you want to be able to have the router/kubernetes to be able to access your namespace.


```
oc create -f allow-from-default-namespace.yml
```

^ this makes your app "browsable"

## Allow Pod access

To allow a certian webapp to access the database run the following...

```
oc create -f allow-to-database.yaml
```

In this example, I am targeting `tier=database` and am allowing things labeled as `tier=frontend`. Now if you want to change these...you need to label ALL these resources as such (not as simple as JUST labeling the pods)

For example...

```
[user@host]$ oc get all -l tier=frontend --no-headers  | awk '{print $1}'
pod/pricelist-allowed-1-sxdpr
replicationcontroller/pricelist-allowed-1
service/pricelist-allowed
deploymentconfig.apps.openshift.io/pricelist-allowed
buildconfig.build.openshift.io/pricelist-allowed
build.build.openshift.io/pricelist-allowed-1
imagestream.image.openshift.io/pricelist-allowed
route.route.openshift.io/pricelist-allowed

[user@host]$ oc get all -l tier=database --no-headers  | awk '{print $1}'
pod/mysql-1-x6pkh
replicationcontroller/mysql-1
service/mysql
deploymentconfig.apps.openshift.io/mysql
```

^ If you want to change the labels in `allow-to-database.yaml` you need to label all of these resources


## Recap

This is all I have to allow webfrontend1 to a db without allowing webfrontend2


```
[user@host]$ oc get networkpolicies
NAME                           POD-SELECTOR    AGE
allow-3306                     tier=database   7m
allow-from-default-namespace   <none>          15m
default-deny                   <none>          15m
```


## Multitenant functionality

If you want to allow pods to communicate from one project to another (i.e. like the multitenant plugin); you'll need to do something like this...

```
oc label ns myproject project=myproject
```

then

```
oc create -f allow-from-namespace.yaml -n yourproject
```

^ This allows pods from the namespace labeled `myproject` to access pods to the `yourproject` namespace

# Egress Rules

To block access from pods within a namespace to go out of the cluster you can run...

```
oc create -f allow-domain.json -n myproject
```

This blocks/allows traffic going outside the OCP cluster. **NOTE** this is an admin task; you have to be `system:admin` or equiv to use Egress rules.
