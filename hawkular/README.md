# Hawkular Metrics

This shows you how to install Hawkular Metrics. This assumes that you got [dynamic storage setup](../cns). Also note that I use ansible variables and those may change. I don't keep this doc very up to date so best to look at [my sample ansible hosts files](../ansible_hostfiles) go verify.

# Installation

First, set up your `/etc/ansible/hosts` file with the following in the `[OSEv3:vars]` section

```
# Metrics
openshift_metrics_install_metrics=true
openshift_metrics_cassandra_storage_type=dynamic
openshift_metrics_cassandra_pvc_size=28Gi
openshift_metrics_cassanda_pvc_storage_class_name=glusterfs-storage-block
openshift_metrics_hawkular_nodeselector={'region':'infra'}
openshift_metrics_heapster_nodeselector={'region':'infra'}
openshift_metrics_cassandra_nodeselector={'region':'infra'}
```

Also verify that you have this under `[OSEv3:vars]` as well

```
openshift_master_dynamic_provisioning_enabled=true
dynamic_volumes_check=False
```

Then run the installer.

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml
```

# Uninstall

To uninstall hawkular; run the same playbook but add `-e openshift_metrics_install_metrics=False`

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml \
-e openshift_metrics_install_metrics=False
```

# Prometheus

Same idea with prometheus; make sure you have something like `[OSEv3:vars]` in your `/etc/ansible/hosts` file

```
## Prometheus Metrics
openshift_hosted_prometheus_deploy=true
openshift_prometheus_namespace=openshift-metrics
openshift_prometheus_node_selector={'region':'infra'}

# Prometheus storage config
openshift_prometheus_storage_access_modes=['ReadWriteOnce']
openshift_prometheus_storage_volume_name=prometheus
openshift_prometheus_storage_volume_size=10Gi
openshift_prometheus_storage_type='pvc'
openshift_prometheus_sc_name="glusterfs-storage"

# For prometheus-alertmanager
openshift_prometheus_alertmanager_storage_access_modes=['ReadWriteOnce']
openshift_prometheus_alertmanager_storage_volume_name=prometheus-alertmanager
openshift_prometheus_alertmanager_storage_volume_size=10Gi
openshift_prometheus_alertmanager_storage_type='pvc'
openshift_prometheus_alertmanager_sc_name="glusterfs-storage"

# For prometheus-alertbuffer
openshift_prometheus_alertbuffer_storage_access_modes=['ReadWriteOnce']
openshift_prometheus_alertbuffer_storage_volume_name=prometheus-alertbuffer
openshift_prometheus_alertbuffer_storage_volume_size=10Gi
openshift_prometheus_alertbuffer_storage_type='pvc'
openshift_prometheus_alertbuffer_sc_name="glusterfs-storage"

openshift_prometheus_node_exporter_image_version=v3.9.25
```

Then run

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-prometheus/config.yml
```

# Misc

If you ran the installer without the `*_nodeselector` options; you can do this to "move" it over to your infra nodes.

```
oc patch ns openshift-infra -p '{"metadata": {"annotations": {"openshift.io/node-selector": "region=infra"}}}'
```
