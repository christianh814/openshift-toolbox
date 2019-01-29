
# Configure docker storage.

Docker’s default loopback storage mechanism is not supported for production use and is only appropriate for proof of concept environments. For production environments, you must create a thin-pool logical volume and re-configure docker to use that volume.

You can use the docker-storage-setup script to create a thin-pool device and configure docker’s storage driver after installing docker but before you start using it. The script reads configuration options from the `/etc/sysconfig/docker-storage-setup` file.

Configure docker-storage-setup for your environment. There are three options available based on your storage configuration:

a) Create a thin-pool volume from the remaining free space in the volume group where your root filesystem resides; this requires no configuration:

`# docker-storage-setup`

b) Use an existing volume group, in this example docker-vg, to create a thin-pool:

```
# echo <<EOF > /etc/sysconfig/docker-storage-setup
VG=docker-vg
SETUP_LVM_THIN_POOL=yes
DATA_SIZE=90%FREE
WIPE_SIGNATURES=true
EOF
# docker-storage-setup
```

c) Use an unpartitioned block device to create a new volume group and thinpool. In this example, the /dev/vdc device is used to create the docker-vg volume group:

```
# cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/vdc
VG=docker-vg
DATA_SIZE=90%FREE
WIPE_SIGNATURES=true
EOF
# docker-storage-setup
```

Verify your configuration. You should have dm.thinpooldev value in the /etc/sysconfig/docker-storage file and a docker-pool device:

```
# lvs
LV                  VG        Attr       LSize  Pool Origin Data%  Meta% Move Log Cpy%Sync Convert
docker-pool         docker-vg twi-a-tz-- 48.95g             0.00   0.44
# cat /etc/sysconfig/docker-storage
DOCKER_STORAGE_OPTIONS=--storage-opt dm.fs=xfs --storage-opt dm.thinpooldev=/dev/mapper/docker--vg-docker--pool
```

Re-initialize docker.

**Warning** This will destroy any docker containers or images currently on the host.
```
    # systemctl stop docker
    # vgremove -ff docker-vg
    # rm -rf /var/lib/docker/*
    # wipefs -a /path/to/dev
    # cat /dev/null > /etc/sysconfig/docker-storage
    # docker-storage-setup
    # systemctl restart docker
```
