# Manage Servers

Here are various notes specific to master/node management in no paticular order

* [Masters](#masters)
* [Nodes](#nodes)

## Masters

Sometimes, in order to deploy pods on them, you'll need to mark your masters `schedulable`

```
root@master# oc adm manage-node ose3-master.example.com --schedulable=true
```

## Nodes

* [Assign Node Roles](#roles)

## Roles

Label for node roles

```
oc label node infra1.cloud.chx node-role.kubernetes.io/infra=true
```

Common roles are...

```
node-role.kubernetes.io/compute: "true"
node-role.kubernetes.io/infra: "true"
node-role.kubernetes.io/master: "true"
```

Your nodes will look like this

```
[root@master1 ~]# oc get nodes
NAME                STATUS    ROLES     AGE       VERSION
app1.cloud.chx      Ready     compute   33d       v1.9.1+a0ce1bc657
app2.cloud.chx      Ready     compute   33d       v1.9.1+a0ce1bc657
app3.cloud.chx      Ready     compute   33d       v1.9.1+a0ce1bc657
cns1.cloud.chx      Ready     compute   33d       v1.9.1+a0ce1bc657
cns2.cloud.chx      Ready     compute   33d       v1.9.1+a0ce1bc657
cns3.cloud.chx      Ready     compute   33d       v1.9.1+a0ce1bc657
infra1.cloud.chx    Ready     infra     33d       v1.9.1+a0ce1bc657
infra2.cloud.chx    Ready     infra     33d       v1.9.1+a0ce1bc657
master1.cloud.chx   Ready     master    33d       v1.9.1+a0ce1bc657
master2.cloud.chx   Ready     master    33d       v1.9.1+a0ce1bc657
master3.cloud.chx   Ready     master    33d       v1.9.1+a0ce1bc657
```

