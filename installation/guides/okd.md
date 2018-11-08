# OKD

This is a HIGH LEVEL howto install the upstream. It's pretty simple. I borrowed A LOT from [Grant Shipley's All-in-One install guide](https://github.com/gshipley/installcentos)

This page assumes you know enough about OpenShift that all you need is a few notes.

## Install CentOS

I installed CentOS with the following in mind

  * 1 Master/2 Nodes
    * 12GB Ram each
    * 4CPUs Each
    * 50GB for root
    * 50GB for container storage
    * 100GB for OCS (formerly CNS)
  * DNS
    * Foward and reverse DNS for all hosts
    * Wildcard entry `*.apps.example.com` pointed to the IP of the master
    * Webconsole entry `ocp.example.com` pointed to the IP of the master
  * Minimal Install
  
## Prep The host

I preped the hosts with the follwing steps borrowed from the [setup script](https://github.com/gshipley/installcentos/blob/master/install-openshift.sh). Note that I **DID NOT** run the script but used to to prepare my hosts

_detailed instructions to come_

## Inventory File

I used my [standard inventory file](https://raw.githubusercontent.com/christianh814/openshift-toolbox/master/ansible_hostfiles/singlemaster) and edited it with stuff taken from [Grant's inventory file](https://github.com/gshipley/installcentos/blob/master/inventory.ini)

I ended up with this [inventory file for OKD 3.11](okd-inventory.ini)

## Install

Install is SOP

NOTE: make sure you get the right branch
```
export VERSION=3.11
git clone https://github.com/openshift/openshift-ansible.git
cd openshift-ansible && git fetch && git checkout release-${VERSION} && cd ..
```

Other than that it's the same...

```
ansible-playbook openshift-ansible/playbooks/prerequisites.yml
ansible-playbook openshift-ansible/playbooks/deploy_cluster.yml
```

## Troubleshooting

List of things I've ran into

### Image version

Had an issue with `openshift-logging` namespace where the images weren't there

```
[root@dhcp-host-81 ~]# oc get pods
NAME                                       READY     STATUS             RESTARTS   AGE
logging-es-data-master-omovbji7-1-deploy   1/1       Running            0          2m
logging-es-data-master-omovbji7-1-lphdr    1/2       ImagePullBackOff   0          2m
logging-fluentd-788fx                      1/1       Running            0          3m
logging-fluentd-7ndvb                      1/1       Running            0          3m
logging-fluentd-sh2b4                      1/1       Running            0          3m
logging-kibana-1-deploy                    1/1       Running            0          4m
logging-kibana-1-zxgvr                     1/2       ImagePullBackOff   0          4m
```

checked to see if I could pull manually

```
[root@dhcp-host-81 ~]# docker pull docker.io/openshift/origin-logging-elasticsearch5:v3.11
Trying to pull repository docker.io/openshift/origin-logging-elasticsearch5 ... 
manifest for docker.io/openshift/origin-logging-elasticsearch5:v3.11 not found
```

So I just pulled the latest...

```
[root@dhcp-host-81 ~]# docker pull docker.io/openshift/origin-logging-elasticsearch5:latest
Trying to pull repository docker.io/openshift/origin-logging-elasticsearch5 ... 
latest: Pulling from docker.io/openshift/origin-logging-elasticsearch5
aeb7866da422: Already exists 
0fc84339b005: Pull complete 
5af964698c82: Pull complete 
Digest: sha256:add3106c24e2759f73259d769db61bd5a25db95111591a0ec7607feac8887ce2
Status: Downloaded newer image for docker.io/openshift/origin-logging-elasticsearch5:latest

[root@dhcp-host-81 ~]# docker pull docker.io/openshift/origin-logging-kibana5:latest
Trying to pull repository docker.io/openshift/origin-logging-kibana5 ... 
latest: Pulling from docker.io/openshift/origin-logging-kibana5
aeb7866da422: Already exists 
0fc84339b005: Already exists 
3b9a249f07fb: Pull complete 
Digest: sha256:3678bf6d9c9e595e60534843e5cfe15471dd6a1fd81593cbdf292e71771663ff
Status: Downloaded newer image for docker.io/openshift/origin-logging-kibana5:latest
```

Then I tagged them

```
 docker tag docker.io/openshift/origin-logging-kibana5:latest docker.io/openshift/origin-logging-kibana5:v3.11
 docker tag docker.io/openshift/origin-logging-elasticsearch5:latest docker.io/openshift/origin-logging-elasticsearch5:v3.11
```

Logging came up!

```
[root@dhcp-host-81 ~]# oc get pods
NAME                                      READY     STATUS    RESTARTS   AGE
logging-es-data-master-omovbji7-1-lphdr   2/2       Running   0          4m
logging-fluentd-788fx                     1/1       Running   0          5m
logging-fluentd-7ndvb                     1/1       Running   0          5m
logging-fluentd-sh2b4                     1/1       Running   0          5m
logging-kibana-1-deploy                   1/1       Running   0          6m
logging-kibana-1-zxgvr                    1/2       Running   0          6m
```
