# OC Cluster Up

This is used to run OpenShift inside a docker container on a Linux host


QnD

1. Download latest `oc` client [here](https://github.com/openshift/origin/releases)

2a. Temp setup

```
yum -y install docker
sed -i '/OPTIONS=.*/c\OPTIONS="--selinux-enabled --insecure-registry 172.30.0.0/16"' /etc/sysconfig/docker
systemctl enable docker
systemctl start docker
NETWORKSPACE=$(docker network inspect -f "{{range .IPAM.Config }}{{ .Subnet }}{{end}}" bridge)
firewall-cmd --permanent --new-zone dockerc
firewall-cmd --permanent --zone dockerc --add-source ${NETWORKSPACE}
firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
firewall-cmd --permanent --zone dockerc --add-port 53/udp
firewall-cmd --permanent --zone dockerc --add-port 8053/udp
firewall-cmd --permanent --zone public --add-port 8443/tcp
firewall-cmd --permanent --zone public --add-port 443/tcp
firewall-cmd --permanent --zone public --add-port 80/tcp
firewall-cmd --permanent --zone public --add-port 53/udp
firewall-cmd --permanent --zone public --add-port 8053/udp
firewall-cmd --reload
oc cluster up --metrics=true --logging=true --public-hostname console.$DOMAIN --routing-suffix apps.$DOMAIN
```

2b. Save config for later

```
yum -y install docker
sed -i '/OPTIONS=.*/c\OPTIONS="--selinux-enabled --insecure-registry 172.30.0.0/16"' /etc/sysconfig/docker
systemctl enable docker
systemctl start docker
NETWORKSPACE=$(docker network inspect -f "{{range .IPAM.Config }}{{ .Subnet }}{{end}}" bridge)
firewall-cmd --permanent --new-zone dockerc
firewall-cmd --permanent --zone dockerc --add-source ${NETWORKSPACE}
firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
firewall-cmd --permanent --zone dockerc --add-port 53/udp
firewall-cmd --permanent --zone dockerc --add-port 8053/udp
firewall-cmd --permanent --zone public --add-port 8443/tcp
firewall-cmd --permanent --zone public --add-port 443/tcp
firewall-cmd --permanent --zone public --add-port 80/tcp
firewall-cmd --permanent --zone public --add-port 53/udp
firewall-cmd --permanent --zone public --add-port 8053/udp
firewall-cmd --reload
mkdir -m 777 -p /ocp-storage/{host-config-dir,host-data-dir,host-volumes-dir}
oc cluster up --metrics=true --logging=true --public-hostname console.$DOMAIN --routing-suffix apps.$DOMAIN \
--host-config-dir=/ocp-storage/host-config-dir \
--host-data-dir=/ocp-storage/host-data-dir \
--host-volumes-dir=/ocp-storage/host-volumes-dir
```

3. Optional (but helpful!) stuff

If you want other versions try this
```
oc cluster up ... \
--image=registry.access.redhat.com/openshift3/ose --version=v3.4.1.5
```

If you want your data from above to persist...

```
oc cluster up ... \
--use-existing-config
```

Newer versions have this handy
```
oc cluster up ... \
 --host-pv-dir=/ocp-storage/openshift.local.pv
```
