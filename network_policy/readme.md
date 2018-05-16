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

## Note
MIGHT Need to run `oc label namespace default name=default`
