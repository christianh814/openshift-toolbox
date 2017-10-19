# Container Native Storage
You can install GlusterFS in a container and run it on OpenShift. Furthermore you can use `heketi` to dynamically create volumes to use. I used this doc mostly and these are my "fast track" notes.

[Official Docs](https://access.redhat.com/documentation/en-us/red_hat_gluster_storage/3.2/html/container-native_storage_for_openshift_container_platform/)

## Prereqs

1) A fully functioning OCP v 3.5Ch environment
2) At least 3 nodes (minimum) with at least 100GB raw/unformated disc attached to them
3) If you have a POC env with one master and two nodes; you're going to __*need*__ to use the master as a node
4) Fully functioning DNS

Thigs to keep in mind (*DO NOT SKIP OVER THIS; PLEASE READ*)

* Ensure that the Trusted Storage Pool is not scaled beyond 100 volumes per 3 nodes per 32G of RAM.
* A trusted storage pool consists of a minimum of 3 nodes/peers.
* Distributed-Three-way replication is the only supported volume type. 

If you want the "quick and dirty" method; [click here](#poweruser)

## Subscribe

On *all* masters/nodes subscribe to the proper RHEL channels and install packages

```
subscription-manager repos --enable=rh-gluster-3-for-rhel-7-server-rpms
yum -y install cns-deploy heketi-client
```

## Firewall

Add this to the `/etc/sysconfig/iptables` file on *all* masters/nodes

```
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 24007 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 24008 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2222 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m multiport --dports 49152:49664 -j ACCEPT
```

Then reload with...

```
systemctl reload iptables
```

Check your work

```
iptables -L
```

## Poweruser

If you have ansible set up; do it with ansible. I've included a playbook to do most of the above.
```
ansible all -m shell -a "subscription-manager repos --enable=rh-gluster-3-for-rhel-7-server-rpms"
ansible-playbook ./host-prepare.yaml
```

## Create OpenShift Project

Create a project for your gluster node

*IF* you have 3 nodes run:

```
oc adm new-project glusterfs
oc project glusterfs
```

If you only have 2 nodes and *need* to use your master as a node; run:

```
oc adm manage-node ose3-master.example.com --schedulable
oc adm new-project glusterfs --node-selector=""
oc project glusterfs
```

Next, enable privileged containers

```
oadm policy add-scc-to-user privileged -z default
```

NOTE:

You *_MAY_* just need to do this in the stead

```
oadm policy add-scc-to-user privileged -z storage-project
```

## Deploying Container-Native Storage

You must first provide a topology file for heketi which describes the topology of the Red Hat Gluster Storage nodes and their attached storage devices.
A sample, formatted topology file (topology-sample.json) is installed with the `heketi-client` package in the `/usr/share/heketi/` directory.

This is the config I used on my AWS instance (I'm using my master as a node) saved as `cns.json`:

```json
{
    "clusters": [
        {
            "nodes": [
                {
                    "node": {
                        "hostnames": {
                            "manage": [
                                "ip-172-31-19-167.us-west-1.compute.internal"
                            ],
                            "storage": [
                                "172.31.19.167"
                            ]
                        },
                        "zone": 1
                    },
                    "devices": [
                        "/dev/xvdf"
                    ]
                },
                {
                    "node": {
                        "hostnames": {
                            "manage": [
                                "ip-172-31-19-240.us-west-1.compute.internal"
                            ],
                            "storage": [
                                "172.31.19.240"
                            ]
                        },
                        "zone": 2
                    },
                    "devices": [
                        "/dev/xvdf"
                    ]
                },
                {
                    "node": {
                        "hostnames": {
                            "manage": [
                                "ip-172-31-24-220.us-west-1.compute.internal"
                            ],
                            "storage": [
                                "172.31.24.220"
                            ]
                        },
                        "zone": 3
                    },
                    "devices": [
                        "/dev/xvdf"
                    ]
                }
            ]
        }
    ]
}
```

__Things to note__

* The `manage` is the hostname (REQUIRED) that openshift sees (i.e. `oc get nodes`) and the `storage` is the ip of that host (REQUIRED)
* The device `/dev/xvdf` is a *RAW* storage deviced attached and unformated. 
* I've ran into trouble with drives less than 100GB...the ones I used are 250GB each. YMMV
* Remeber to increment your `zone` number in the json or you're going to have a bad time

Install with

```
cns-deploy -n glusterfs -g cns.json  -y -c oc
```

Command options are

* `-n` : namespace/project name
* `-g` : Path to the json file
* `-y` : Assume "yes" to questions
* `-c` : The command line utility to use (you can use `oc` or `kubectl`)

__NOTE: I had the error of glusterfs not comming up in time so I just reran with:__

```
cns-deploy -n glusterfs -g cns.json  -y -c oc --load
```

The `--load` means that it skips trying to create things and just relaods the config.

## Configure Heketi CLI

Export `HEKETI_CLI_SERVER` with the route so you can connect to the API

```
oc get routes
export  HEKETI_CLI_SERVER=http://heketi-<project_name>.<sub_domain_name>
```
*OR* (if you're a poweruser)

```
export  HEKETI_CLI_SERVER=http://$(oc get routes heketi --no-headers -n glusterfs | awk '{print $2}')
```

I would save this in `/etc/bashrc`

Run the following command to see if everything is working

```
heketi-cli topology info
```

## Dynamically Creating PVs from PVCs

You need to first create a `storageClass` (it might be different now - look [here](https://docs.openshift.com/container-platform/latest/install_config/storage_examples/gluster_dynamic_example.html#create-a-storage-class-for-your-glusterfs-dynamic-provisioner) )

```yaml
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: gluster-container
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://heketi-glusterfs.apps.example.com"
  restuser: "admin"
  secretNamespace: "default"
  secretName: "heketi-secret"
  volumetype: "replicate:3"
```

Things to note

* `resturl`  : The route you exported earlier (this can be the `svc` ip address if you want)
* `restuser` : The user to hit the API with (by default it's `admin` so stick with that)
* `secretNamespace` : Namespace where your secret is (more on that below)
* `secretName` : The name of that secret
* `volumetype` : It specifies the volume type that is being used. Distributed-Three-way replication is the only supported volume type. You can also put `volumetype: none` for testing purposes
* If you'd like to make this a default storage class; add an annotation. Here's an [example](gluster-default-storageclass.yaml)

Now, create a secret; by default heketi uses "My Secret" as the password so run...

```
echo -n "My Secret" | base64
TXkgw2VjcmV0
```

Now use that output to create the secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: heketi-secret
  namespace: default
data:
  key: TXkgw2VjcmV0
type: kubernetes.io/glusterfs
```

Load both of these files

```
oc create -f glusterfs-secret.yaml
oc create -f glusterfs-storageclass.yaml
```

## Block Storage

*WIP*

The block provisioner can be used for block storage. iSCSi is used for this purpose. First you need to install the required packages on all nodes

```
ansible all -m shell -a "yum -y install iscsi-initiator-utils device-mapper-multipath"
```

Next, initiate the build of the `/etc/multipath.conf` file

```
ansible all -m shell -a "mpathconf --enable"

```

Now create the `multipath.conf` file locally under `/tmp`

```
# LIO iSCSI
devices {
        device {
                vendor "LIO-ORG"
                user_friendly_names "yes" # names like mpatha
                path_grouping_policy "failover" # one path per group
                path_selector "round-robin 0"
                failback immediate
                path_checker "tur"
                prio "const"
                no_path_retry 120
                rr_weight "uniform"
        }
}
```

Copy this file over to all the nodes with the proper permissions
```
ansible all -m copy -a "src=/tmp/multipath.conf dest=/etc/multipath.conf owner=root group=root mode=0600"
```

Make sure SELinux labels are correct
```
ansible all -m shell -a "restorecon -vR /etc/multipath.conf"
```

Pull the block provisioner
```
ansible all -m shell -a "docker pull rhgs3/rhgs-gluster-block-prov-rhel7"
```

## Profit!

Now you should be able to create a pvc and have that bound on the WebUI
