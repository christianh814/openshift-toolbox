# Metrics

This shows you how to install Metrics on OpenShift. This assumes that you got [dynamic storage setup](../cns). Also note that I use ansible variables and those may change. I don't keep this doc very up to date so best to look at [my sample ansible hosts files](../ansible_hostfiles) go verify.

# Installation Hawkular

First, set up your `/etc/ansible/hosts` file with the following in the `[OSEv3:vars]` section

```
# Metrics
openshift_metrics_install_metrics=true
openshift_metrics_cassandra_pvc_size=20Gi
openshift_metrics_cassandra_storage_type=dynamic
openshift_metrics_cassandra_pvc_storage_class_name=glusterfs-storage-block
openshift_metrics_hawkular_nodeselector={'node-role.kubernetes.io/infra':'true'}
openshift_metrics_heapster_nodeselector={'node-role.kubernetes.io/infra':'true'}
openshift_metrics_cassandra_nodeselector={'node-role.kubernetes.io/infra':'true'}
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

# Uninstall Hawkular

To uninstall hawkular; run the same playbook but add `-e openshift_metrics_install_metrics=False`

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml \
-e openshift_metrics_install_metrics=False
```

# Prometheus/Grafana

Same idea with prometheus; make sure you have something like `[OSEv3:vars]` in your `/etc/ansible/hosts` file

```
# Prometheus Metrics
openshift_cluster_monitoring_operator_install=true
openshift_cluster_monitoring_operator_prometheus_storage_enabled=true
openshift_cluster_monitoring_operator_alertmanager_storage_enabled=true
openshift_cluster_monitoring_operator_prometheus_storage_capacity=15Gi
openshift_cluster_monitoring_operator_alertmanager_storage_capacity=15Gi
openshift_cluster_monitoring_operator_node_selector={'node-role.kubernetes.io/infra':'true'}
```

Then run

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/openshift-prometheus/config.yml
```

(NOTE: Grafana installs automatically)

# Misc Hawkular

If you ran the installer without the `*_nodeselector` options; you can do this to "move" it over to your infra nodes.

```
oc patch ns openshift-infra -p '{"metadata": {"annotations": {"openshift.io/node-selector": "node-role.kubernetes.io/infra=true"}}}'
```
