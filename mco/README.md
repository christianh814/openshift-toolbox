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
      version: 2.2.0
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

```
oc create -f 
```
