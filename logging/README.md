# Logging

OpenShift aggr logging is done on the EFK stack. This guide assumes that you're running [CNS](../cns)

# Installation

To Install add the following under `[OSEv3:vars]` in `/etc/ansible/hosts`

```
# Logging
openshift_logging_install_logging=true
openshift_logging_es_pvc_dynamic=true
openshift_logging_es_pvc_size=20Gi
openshift_logging_es_pvc_storage_class_name=glusterfs-storage-block
openshift_logging_curator_nodeselector={'node-role.kubernetes.io/infra':'true'}
openshift_logging_es_nodeselector={'node-role.kubernetes.io/infra':'true'}
openshift_logging_kibana_nodeselector={'node-role.kubernetes.io/infra':'true'}
openshift_logging_es_memory_limit=4G
```

Just like [metrics](../metrics), you may need this for dynamic storage

```
openshift_master_dynamic_provisioning_enabled=true
dynamic_volumes_check=False
```

Next run the installer

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-logging/config.yml
```

# Uninstall

To uninstall, run the same playbook with `-e openshift_logging_install_logging=False`

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-logging/config.yml \
-e openshift_logging_install_logging=False
```

# Misc

If you messed up and didn't include `*_nodeselector`; then moved them with

```
oc get dc -n logging
oc patch dc/<dc name> -n loggin -p '{"spec":{"template":{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra":"true"}}}}}'
```
