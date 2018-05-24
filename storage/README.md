# Storage

OpenShift abstracts storage, and it's up to the administrator to setup/configure/manage storage. Here is info, again, in no paticular order

* [Host Path](#host-path)

CNS (Container Native Storage), is a whole other beast. Notes for that can be found [here](../cns)

## Host Path

If you are going to add `hostPath` for your application, then you might need to do the following

```
oc edit scc privileged
```

And add under users
```
- system:serviceaccount:default:registry
- system:serviceaccount:default:docker
```

Maybe this will work too? (prefered

```
oc adm policy add-scc-to-user privileged -z registry
oc adm policy add-scc-to-user privileged -z router
```

If you're using `/registry` as your registry storage...

```
semanage fcontext -a -t svirt_sandbox_file_t "/registry(/.*)?"
restorecon -vR /registry
```

Or

```
chcon -R -t svirt_sandbox_file_t /registry
```
