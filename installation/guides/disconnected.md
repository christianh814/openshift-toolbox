# Disconnected Install

There are many things to take into account. I will write "highlevel" notes here but YMMV. Pull requests welcome but I may/maynot merge them.

* [Sync Repositories](#sync-repos)
* [Sync Registry](#sync-registry)
* [Install OpenShift](#install-openshift)

NOTE: Most of this is hacked together from [Nick's Repo](https://github.com/nnachefski/ocpstuff/blob/master/install/setup-disconnected.md)

## Sync Repos

If you're not using SAT or another repo that is pre-synced; you'll have to create your own. This is straight foward so I won't elaborate too much...

__Subscribe your Server__

Subscribe to all the channels you want to sync (required even though this server won't be "using" them)

```
subscription-manager register
subscription-manager attach --pool=${pool_id}
subscription-manager repos  --disable=*
yum-config-manager --disable \*
subscription-manager repos \
    --enable=rhel-7-server-rpms \
    --enable=rhel-7-server-extras-rpms \
    --enable=rhel-7-server-ose-3.11-rpms \
    --enable=rhel-7-server-ansible-2.6-rpms \
    --enable=rh-gluster-3-client-for-rhel-7-server-rpms
```

__Install/Configure Apache__

```
yum -y install httpd
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```

__Sync The Repos__

I usually do this in a script but here is the "straight" `for` loop.

```
for repo in rhel-7-server-rpms rhel-7-server-extras-rpms rhel-7-server-ose-3.11-rpms rhel-7-server-ansible-2.6-rpms rh-gluster-3-client-for-rhel-7-server-rpms
do
  reposync --gpgcheck -lm --repoid=${repo} --download_path=/var/www/html/repos
  createrepo -v /var/www/html/repos/${repo} -o /var/www/html/repos/${repo}
done
```

You'll probably need to run `restorecon`

```
/sbin/restorecon -vR /var/www/html
```

You can start/enable Apache

```
systemctl enable --now httpd
```

__Create Repo Files__

You need to create a repo file on ALL servers (masters/infra/nodes/ocs). Usually I create this as `/etc/yum.repos.d/ocp.repo`


```
[rhel-7-server-rpms]
name=rhel-7-server-rpms
baseurl=http://repo.example.com/repos/rhel-7-server-rpms
enabled=1
gpgcheck=0

[rhel-7-server-extras-rpms]
name=rhel-7-server-extras-rpms
baseurl=http://repo.example.com/repos/rhel-7-server-extras-rpms
enabled=1
gpgcheck=0

[rhel-7-server-ose-3.11-rpms]
name=rhel-7-server-ose-3.11-rpms
baseurl=http://repo.example.com/repos/rhel-7-server-ose-3.11-rpms
enabled=1
gpgcheck=0

[rhel-7-server-ansible-2.6-rpms]
name=rhel-7-server-ansible-2.6-rpms
baseurl=http://repo.example.com/repos/rhel-7-server-ansible-2.6-rpms
enabled=1
gpgcheck=0

[rh-gluster-3-client-for-rhel-7-server-rpms]
name=rh-gluster-3-client-for-rhel-7-server-rpms
baseurl=http://repo.example.com/repos/rh-gluster-3-client-for-rhel-7-server-rpms
enabled=1
gpgcheck=0
```

## Sync Registry

Now you need to sync the docker repo. These are high level notes and assumes you know what you're doing

__Subscribe The Registry Server__

Subscribe to the proper channels

```
subscription-manager register
subscription-manager attach --pool=${pool_id}
subscription-manager repos  --disable=*
yum-config-manager --disable \*
subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-ose-3.11-rpms --enable=rhel-7-fast-datapath-rpms --enable=rhel-7-server-ansible-2.6-rpms --enable=rh-gluster-3-client-for-rhel-7-server-rpms
```

__Install Docker__

Install and enable the registry and docker

```
yum -y install docker-distribution docker
systemctl enable docker-distribution --now
systemctl enable --now docker
```

Export your repo hostname (or whatever DNS is pointing to the server as)

```
export MY_REPO=$(hostname)
```

__Generate Certs__

This step is **OPTIONAL** ...skip this if you're not going to verify the cert of this server

```
mkdir -p /etc/docker/certs.d/$MY_REPO
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout /etc/docker/certs.d/$MY_REPO/$MY_REPO.key -x509 -days 365 -out /etc/docker/certs.d/$MY_REPO/$MY_REPO.cert
```

Tell docker-registry to use this cert

```
cat <<EOF >> /etc/docker-distribution/registry/config.yml
    headers:
        X-Content-Type-Options: [nosniff]
    tls:
        certificate: /etc/docker/certs.d/$MY_REPO/$MY_REPO.cert
        key: /etc/docker/certs.d/$MY_REPO/$MY_REPO.key
EOF
```

Change the port of you don't want to use 5000

```
sed -i 's/\:5000/\:443/' /etc/docker-distribution/registry/config.yml
```

Restart the service if you made any changes

```
systemctl restart docker-distribution
```

__Install Skopeo__

You'll need certian python modules to do the sync so install them with epel (then disable epel)

```
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y python34 python34-pip
yum-config-manager --disable epel
```

Install Skopeo

```
yum install -y skopeo
```

__Sync Repos__

If you haven't export your repo's DNS/Hostname (you can use the IP too if you want). Also export your source repo

```
export MY_REPO=$(hostname)
export SRC_REPO=registry.access.redhat.com
```

If you're using Red Hat's registry; you'll need to login in order to pull the images

```
docker login $SRC_REPO
```

Grab the files and script provided by Nick

```
cd ~ 
wget https://raw.githubusercontent.com/nnachefski/ocpstuff/master/scripts/import-images.py 
chmod +x import-images.py
wget https://raw.githubusercontent.com/nnachefski/ocpstuff/master/images/core_images.txt
wget https://raw.githubusercontent.com/nnachefski/ocpstuff/master/images/app_images.txt
wget https://raw.githubusercontent.com/nnachefski/ocpstuff/master/images/mw_images.txt
```

Now loop trough these and sync them to your repo (I'd do this in a `tmux` session and I'd go grab lunch)

```
for i in core_images.txt app_images.txt mw_images.txt; do
  ./import-images.py docker $SRC_REPO $MY_REPO -d -l $i
  ./import-images.py docker $SRC_REPO $MY_REPO -d -l $i
  ./import-images.py docker $SRC_REPO $MY_REPO -d -l $i
done
```

## Install OpenShift

Now you can install OpenShift like you would normally. 
