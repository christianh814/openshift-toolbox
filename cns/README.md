# CNS

CNS (Container Native Storage) is a way to dynamically create file/object/block storage leverging glusterfs for OpenShift. Here are some quick notes in no paticular order

* [Installation](#installation)
* [Heketi](#heketi)
* [AIO Install](#aio-install)

## Installation

There are two methods to install CNS

* [Using the Ansible Host File](../ansible_hostfiles/singlemaster#L26-L33)
* [Post OpenShift Installation](https://github.com/RedHatWorkshops/openshiftv3-ops-workshop/blob/master/cns.md)

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

I expanded a volume using:

```
heketi-cli volume expand --volume=a533436be2ced2b46f2d48238c7b46f3 --expand-size=5
```

The `--expand-size` is how much you want to ADD to the existing storage. For example; if the volume was `10GB` and you passwd `--expand-size=5` it'll now be `15GB`.

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

## AIO Install

"All in One" Install is running CNS on a single node (only for testing). 
