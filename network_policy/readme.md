# NetworkPolicy QnD

Make sure you're in the right project

```
oc project myproject
```

First Run a deny all rule:

```
oc create -f default-deny.yaml
```
Verify label for allow with:

```
oc get pods -l tier=frontend
```

Then run the allow frontend (making sure the label is the same):

```
oc create -f allow-frontend-pa.yaml
```

Now allow the "bad" one

```
oc create -f allow-frontend-pn.yaml
```

Allow the "good" web server to access the db


```
oc create -f allow-pa-database.yaml
```

*NOTE*: If you want to allow pods from one project to another; you'll need to do something like this...

```
oc label ns myproject name=myproject
```

Then

```
oc create -f allow-from-namespace.yaml
```

## Note
MIGHT Need to run `oc label namespace default name=default`

# Egress Rules

To block access from pods within a namespace to go out of the cluster you can run...

```
oc create -f allow-domain.json -n myproject
```
