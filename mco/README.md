# Machine Config Operator

I'll write more when I have time.

## Example

The following config can be found [here](examples/mcp-with-mc.yaml)

```yaml

apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: worker-bm
spec:
  machineConfigSelector:
    matchExpressions:
      - {key: machineconfiguration.openshift.io/role, operator: In, values: [worker,worker-bm]}
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/worker-bm: ""
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker-bm
  name: 50-worker-bm
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 3.1.0
    networkd: {}
    passwd: {}
    storage:
      files:
        - path: "/etc/foo/foo.conf"
          filesystem: root
          mode: 420
          contents:
            source: data:;base64,UmVkIEhhdCBpcyBiZXR0ZXIgdGhhbiBWTXdhcmUhCg==
        - path: "/etc/foo/foo-other.conf"
          filesystem: root
          mode: 420
          contents:
            source: data:;base64,T3BlblNoaWZ0IGlzIHRoZSBiZXN0Cg==
```

Do an oc create of that file

```shell
oc create -f https://raw.githubusercontent.com/christianh814/openshift-toolbox/master/mco/examples/mcp-with-mc.yaml
```

Then label one of your nodes

```
oc label node  worker1.ocp4.example.com node-role.kubernetes.io/worker-bm=""
```

You'll see something like this

```
oc get nodes
NAME                       STATUS   ROLES              AGE   VERSION
master0.ocp4.example.com   Ready    master             50m   v1.16.2
master1.ocp4.example.com   Ready    master             50m   v1.16.2
master2.ocp4.example.com   Ready    master             50m   v1.16.2
worker0.ocp4.example.com   Ready    worker             50m   v1.16.2
worker1.ocp4.example.com   Ready    worker,worker-bm   50m   v1.16.2
```

Since `worker1.ocp4.example.com` matches both `worker` MCP and `worker-bm`, it'll get both MCPs. But since `worker1.ocp4.example.com` is the only one that matches `worker-bm` MCP. It's the only one with the `/etc/foo/` contents.
