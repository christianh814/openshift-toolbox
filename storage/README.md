# Storage

OpenShift abstracts storage, and it's up to the administrator to setup/configure/manage storage. Here is info, again, in no paticular order

* [Host Path](#host-path)
* [NFS](#nfs)
* [AWS](#aws)
* [CNS](../cns)

## Host Path

If you are going to add `hostPath` for your application, then you might need to do the following

```
oc edit scc privileged
```

And add under users
```
- system:serviceaccount:default:registry
- system:serviceaccount:default:docker
```

Maybe this will work too? (prefered

```
oc adm policy add-scc-to-user privileged -z registry
oc adm policy add-scc-to-user privileged -z router
```

If you're using `/registry` as your registry storage...

```
semanage fcontext -a -t svirt_sandbox_file_t "/registry(/.*)?"
restorecon -vR /registry
```

Or if `chcon` is your thing...do one of these two

```
chcon -R -t svirt_sandbox_file_t /registry
### OR
chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 /registry
```


You can also use a "raw" device for `hostPath` and have a pod/container use it. Below is an example (assuming you are, as stated above, privileged). Note that the `nodeSelector` is important since you're specifying a disk (it's also important when specifying a path too)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: welcome-local
spec:
  nodeSelector:
    myapp: welcome-local
  containers:
  - image: redhatworkshops/welcome-php
    name: welcome-local-container
    volumeMounts:
    - mountPath: /data
      name: local-dir
  volumes:
  - name: local-dir
    hostPath:
      # If type is "BlockDevice" then this is the dir on disk
      path: /path/to/dir
      # type can also be "BlockDevice"
      type: Directory
```

Note that if `fsType` isn't specified under `hostPath:` then it uses `ext4`

## NFS

NFS is a supported protocol and the most common.

* [Setting Up NFS](#setting-up-nfs)
* [NFS Master Config](#nfs-master-config)
* [NFS Client Config](#nfs-client-config)

### Setting Up NFS

Installing/setting up NFS is beyond the scope of this paticular doc; but I do have notes on how to install an NFS server

* [Linux NFS Server Setup](https://github.com/christianh814/notes/blob/master/documents/nfs_notes.md#nfs-v4)
* [Ansible Config](#ansible-config)

#### Ansible Config

You can use the ansible installer to install NFS for you.

1. Set up your `[OSEv3:children]` to include an `nfs` option. It'll look like this.

```
[OSEv3:children]
masters
nodes
etcd
```

2. Then add an `[nfs]` section with the nfs server's hostname/ip

```
[nfs]
nfs.example.com
```

3. In your `[OSEv3:vars]` section; you can set up your registry, etc to use NFS

```
# NFS Host Group
# An NFS volume will be created with path "nfs_directory/volume_name"
# on the host within the [nfs] host group.  For example, the volume
# path using these options would be "/exports/registry"
openshift_hosted_registry_storage_kind=nfs
openshift_hosted_registry_storage_access_modes=['ReadWriteMany']
openshift_hosted_registry_storage_nfs_directory=/exports
openshift_hosted_registry_storage_nfs_options='*(rw,root_squash)'
openshift_hosted_registry_storage_volume_name=registry
openshift_hosted_registry_storage_volume_size=50Gi
```
### NFS Master Config

First (after creating/exporting storage on the NFS server), create the PV (persistant volume) definition

```
{
  "apiVersion": "v1",
  "kind": "PersistentVolume",
  "metadata": {
    "name": "pv0001"
  },
  "spec": {
    "capacity": {
        "storage": "20Gi"
        },
    "accessModes": [ "ReadWriteMany" ],
    "nfs": {
        "path": "/var/export/vol1",
        "server": "nfs.example.com"
    }
  }
}
```


Create this object as the administrative user

```
root@master# oc login -u system:admin
root@master# oc create -f pv0001.json
persistentvolumes/pv0001
```

This defines a volume for OpenShift projects to use in deployments. The storage should correspond to how much is actually available (make each volume a separate filesystem if you want to enforce this limit). Take a look at it now:

```
root@master# oc describe persistentvolumes/pv0001
Name:		pv0001
Labels:		<none>
Status:		Available
Claim:
Reclaim Policy:	%!d(api.PersistentVolumeReclaimPolicy=Retain)
Message:	%!d(string=)
```

### NFS Client Config

Now on the client side...

Before you add the PV make sure you allow containers to mount NFS volumes

```
root@master# setsebool -P virt_use_nfs=true
root@node1#  setsebool -P virt_use_nfs=true
root@node2#  setsebool -P virt_use_nfs=true
```

Now that the administrator has provided a PersistentVolume, any project can make a claim on that storage. We do this by creating a PersistentVolumeClaim (pvc) that specifies what kind and how much storage is desired:

```
{
  "apiVersion": "v1",
  "kind": "PersistentVolumeClaim",
  "metadata": {
    "name": "claim1"
  },
  "spec": {
    "accessModes": [ "ReadWriteMany" ],
    "resources": {
      "requests": {
        "storage": "20Gi"
      }
    }
  }
}
```

We can have alice do this in the project you created (note accessmodes/storage-size must match):

```
user@host$ oc login -u alice
user@host$ oc create -f pvclaim.json
persistentvolumeclaims/claim1
```

This claim will be bound to a suitable PersistentVolume (one that is big enough and allows the requested accessModes). The user does not have any real visibility into PersistentVolumes, including whether the backing storage is NFS or something else; they simply know when their claim has been filled ("bound" to a PersistentVolume).

```
user@host$ oc get pvc
NAME      LABELS    STATUS    VOLUME
claim1    map[]     Bound     pv0001
```

Finally, we need to modify the DeploymentConfig to specify that this volume should be mounted

```
oc volumes dc/gogs --add --claim-name=gogs-repos-claim --mount-path=/home/gogs/gogs-repositories -t persistentVolumeClaim
oc volumes dc/gogs-postgresql --add --name=pgsql-data --claim-name=pgsql-claim --mount-path=/var/lib/pgsql/data -t persistentVolumeClaim --overwrite
```

Take special note that you're overwriting the right `--name`. Find out with `oc volume dc <myapp> --list`

## AWS

You can set up AWS `ebs` volumes for dynamic storage provisioning

* [AWS Setup](#aws-setup)
* [AWS Config](#aws-config)

### AWS Setup

You can set it up with the following steps. You'll need to export `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` before you run the playbook.

1. Set up the following in `[OSEv3:vars]`

```
##  AWS
openshift_cloudprovider_kind=aws
openshift_cloudprovider_aws_access_key="{{ lookup('env','AWS_ACCESS_KEY_ID') }}"
openshift_cloudprovider_aws_secret_key="{{ lookup('env','AWS_SECRET_ACCESS_KEY') }}"
```

2. If you'd like, set up the registry for object storage

```
# Registry Storage
openshift_hosted_registry_storage_kind=object
openshift_hosted_registry_storage_provider=s3
openshift_hosted_registry_storage_s3_accesskey="{{ lookup('env','AWS_ACCESS_KEY_ID') }}"
openshift_hosted_registry_storage_s3_secretkey="{{ lookup('env','AWS_SECRET_ACCESS_KEY') }}"
openshift_hosted_registry_storage_s3_bucket=bucket_name
openshift_hosted_registry_storage_s3_region=us-west-2
openshift_hosted_registry_storage_s3_chunksize=26214400
openshift_hosted_registry_storage_s3_rootdirectory=/registry
openshift_hosted_registry_pullthrough=true
openshift_hosted_registry_acceptschema2=true
openshift_hosted_registry_enforcequota=true
```

### AWS Config

[More Info](https://docs.openshift.com/container-platform/latest/install_config/persistent_storage/dynamically_provisioning_pvs.html#aws-elasticblockstore-ebs)

As an admin on the master.

```
[root@ip-172-31-22-210 ~]# cat aws-ebs-class.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: aws-slow
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  zone: us-west-1b
  iopsPerGB: "10"
  encrypted: "false"
[root@ip-172-31-22-210 ~]# oc create -f aws-ebs-class.yaml
storageclass "aws-slow" created
[root@ip-172-31-22-210 ~]# oc get storageclass
NAME       TYPE
aws-slow   kubernetes.io/aws-ebs
```

Now on the client side

```
[chernand@chernand ~]$ cat aws-ebs.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: gogs-claim
 annotations:
   volume.beta.kubernetes.io/storage-class: aws-slow
spec:
 accessModes:
  - ReadWriteOnce
 resources:
   requests:
     storage: 10Gi
[chernand@chernand ~]$ oc create -f aws-ebs.yaml
persistentvolumeclaim "gogs-claim" created
[chernand@chernand ~]$ oc get pvc
NAME         STATUS    VOLUME                                     CAPACITY   ACCESSMODES   AGE
gogs-claim   Bound     pvc-a3268768-dea9-11e6-b791-02d2b538cbc2   10Gi       RWO           2s
```

You should be able to see it on the server side now

```
[root@ip-172-31-22-210 ~]# oc get pv
NAME                                       CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM              REASON    AGE
pvc-a3268768-dea9-11e6-b791-02d2b538cbc2   10Gi       RWO           Delete          Bound     infra/gogs-claim             10s
```

To setup a default class

```
oc annotate storageclass aws-slow storageclass.kubernetes.io/is-default-class="true"
```
