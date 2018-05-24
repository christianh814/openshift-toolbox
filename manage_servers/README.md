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

TK
