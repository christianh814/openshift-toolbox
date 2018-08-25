# CNS

CNS (Container Native Storage) is a way to dynamically create file/object/block storage leverging glusterfs for OpenShift. Here are some quick notes in no paticular order

* [Installation](#installation)
* [Heketi](#heketi)
* [AIO Install](#aio-install)

## Installation

There are two methods to install CNS

* [Using the Ansible Host File](../ansible_hostfiles/singlemaster#L26-L33) (see note below)
* [Post OpenShift Installation](https://github.com/RedHatWorkshops/openshiftv3-ops-workshop/blob/master/cns.md)

Note: For the ansible based installation; you can add the following if you want a specific node group for the storage nodes (if you have "standalone" storage nodes). Just add the following options

```
openshift_node_groups=[{'name': 'node-config-master', 'labels': ['node-role.kubernetes.io/master=true']}, {'name': 'node-config-infra', 'labels': ['node-role.kubernetes.io/infra=true']}, {'name': 'node-config-compute', 'labels': ['node-role.kubernetes.io/compute=true']}, {'name': 'node-config-storage', 'labels': ['node-role.kubernetes.io/storage=true']}]
```

Then in you `[nodes]` section add `openshift_node_group_name='node-config-storage'` for your storage nodes

```
storage1.cloud.chx openshift_node_group_name='node-config-storage'
storage2.cloud.chx openshift_node_group_name='node-config-storage'
storage3.cloud.chx openshift_node_group_name='node-config-storage'
```

## Heketi

I installed `heketi-cli` from my fedora box

```
dnf -y install heketi-client
```

On OpenShift I grabbed the following info

__Hostname__

```
oc get routes -n glusterfs -o jsonpath='{.items[*].spec.host}{"\n"}'
```

__Token__

```
oc get secret heketi-storage-admin-secret -n glusterfs  -o jsonpath='{.data.key}' | base64 -d
```

__Username__

The default is `admin`

Now export these

```
export HEKETI_CLI_SERVER=http://heketi-storage-glusterfs.apps.172.16.1.10.nip.io
export HEKETI_CLI_USER=admin
export HEKETI_CLI_KEY="kiCN5liH2NlENiB3VVZC5xyzfYEkJoRJCW3TZtbDjJY$"
```

You should be able to administer now

```
heketi-cli volume list
Id:4929364e921514486f147380d70d8119    Cluster:ef045a0b9a13c955a717ab4d6b4e1e3b    Name:heketidbstorage
Id:a533436be2ced2b46f2d48238c7b46f3    Cluster:ef045a0b9a13c955a717ab4d6b4e1e3b    Name:glusterfs-registry-volume
Id:a705b4e18c4a0d82f0223f8a994dd0f4    Cluster:ef045a0b9a13c955a717ab4d6b4e1e3b    Name:vol_a705b4e18c4a0d82f0223f8a994dd0f4
```

__Expanding Volume__

I expanded a volume using:

```
heketi-cli volume expand --volume=a533436be2ced2b46f2d48238c7b46f3 --expand-size=5
```

The `--expand-size` is how much you want to ADD to the existing storage. For example; if the volume was `10GB` and you passwd `--expand-size=5` it'll now be `15GB`.

__Adding Disks__

If you added another disk to your nodes, for example `/dev/vdd` you can add them to your CNS cluster like so.

```
[root@master01 ~]# heketi-cli node list
Id:8349739b559a1bb199ed0736dfc8d7c8     Cluster:ccf9f31f1e534178ed541398290d02b3
Id:b6782be573f6b55eeedba603bf2c34c4     Cluster:ccf9f31f1e534178ed541398290d02b3
Id:d15e22573b033749fcb708b4969ad795     Cluster:ccf9f31f1e534178ed541398290d02b3

[root@master01 ~]# heketi-cli device add --name=/dev/vdd --node=8349739b559a1bb199ed0736dfc8d7c8
Device added successfully

[root@master01 ~]# heketi-cli device add --name=/dev/vdd --node=b6782be573f6b55eeedba603bf2c34c4
Device added successfully

[root@master01 ~]# heketi-cli device add --name=/dev/vdd --node=d15e22573b033749fcb708b4969ad795
Device added successfully
```

__Expand OCS (CNS) Cluster__

Added a GlusterFS device by first labeling the node

```
oc label node node4.example.com glusterfs=storage-host
```

Then (you may not need to do this YMMV) add the ports on the firewall on the node you're adding under `/etc/sysconfig/iptables` (restart `iptables` after)

```
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 24007 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 24008 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2222 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m multiport --dports 49152:49664 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 24010 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 3260 -j ACCEPT
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT
```

Now add the node with `heketi-cli`

```
[root@master01 ~]# heketi-cli node add --zone=1 --cluster=597fceb5d6c876b899e48f599b988f54 --management-host-name=node4.example.com --storage-host-name=192.168.10.104
```

Add the disk

```
[root@master01 ~]# heketi-cli device add --name=/dev/sdc --node=095d5f26b56dc6c64564a9bc17338cbf
```

## AIO Install

"All in One" Install is running CNS on a single node (only for testing).  Once you've installed an [all-in-one](https://raw.githubusercontent.com/christianh814/openshift-toolbox/master/ansible_hostfiles/all-in-one) openshift server follow these steps

### Set Up

Set up the prereqs as you would normally following [this howto](https://github.com/RedHatWorkshops/openshiftv3-ops-workshop/blob/master/cns.md#container-native-storage). Here are the "cliff notes" from that doc (**BUT FOLLOW THAT DOC, DON'T SKIP...RAVI, I'M LOOKING AT YOU!!!!**)

```
git clone https://github.com/RedHatWorkshops/openshiftv3-ops-workshop
cd openshiftv3-ops-workshop
ansible-playbook ./resources/cns-host-prepare.yaml
oc adm new-project glusterfs
oc project glusterfs
oc adm policy add-scc-to-user privileged -z default -n glusterfs
```

Next create a `cns.json` file that specifies your node and the disk you're using

```
{
    "clusters": [
        {
            "nodes": [
                {
                    "node": {
                        "hostnames": {
                            "manage": [
                                "master.ocp.172.16.1.47.nip.io"
                            ],
                            "storage": [
                                "172.16.1.47"
                            ]
                        },
                        "zone": 1
                    },
                    "devices": [
                        "/dev/vdb"
                    ]
                }
            ]
        }
    ]
}
```

### Hack the deployer

You'll need to edit `cns-deploy` to do some things that aren't currently supported officially by Red Hat

```
vim `which cns-deploy`
```

Here you'll looking for a line that has `setup-openshift-heketi-storage` command option. It's around line `874`. It looks like this...

```
eval_output "${heketi_cli} setup-openshift-heketi-storage --listfile=/tmp/heketi-storage.json --image rhgs3/rhgs-volmanager-rhel7:v3.9.0 2>&1"
```

You'll need to **change** this line and add `--durability none` to it...in the end it'll look like this

```
eval_output "${heketi_cli} setup-openshift-heketi-storage --durability none --listfile=/tmp/heketi-storage.json --image rhgs3/rhgs-volmanager-rhel7:v3.9.0 2>&1"
```

In **3.10** I needed to run this...

```
sed -i 's/--show-all//g' `which cns-deploy`
```

### Install CNS

Now you can run `cns-deploy` that will create a "one node cns pod"

```
cns-deploy -n glusterfs -g -y -c oc  --no-block  --no-object cns.json
```

Verify with 

```
[root@master ~]# oc get pods -n glusterfs
NAME              READY     STATUS    RESTARTS   AGE
glusterfs-jbhmd   1/1       Running   0          35m
heketi-1-2d67k    1/1       Running   0          33m
```

Now create a storage class, make sure you add `volumetype: "none"`, this makes it a "distributed"  volume of one disk

```
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: gluster-container
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://heketi-glusterfs.apps.172.16.1.47.nip.io"
  restuser: "admin"
  secretNamespace: "default"
  secretName: "heketi-secret"
  volumetype: "none"
```

Create the secret file (SOP here...nothing special)

```
apiVersion: v1
kind: Secret
metadata:
  name: heketi-secret
  namespace: default
data:
  key: TXkgU2VjcmV0
type: kubernetes.io/glusterfs
```

Now load these

```
oc create -f glusterfs-secret.yaml
oc create -f glusterfs-storageclass.yaml
```

Set it up as your default storageclass if you wish

```
[root@master ~]# oc annotate storageclass gluster-container storageclass.kubernetes.io/is-default-class="true"
storageclass "gluster-container" annotated

[root@master ~]# oc get sc
NAME                          PROVISIONER               AGE
gluster-container (default)   kubernetes.io/glusterfs   30m
```

That's it!
