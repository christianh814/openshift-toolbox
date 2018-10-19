# Disconnected Install

There are many things to take into account. I will write "highlevel" notes here but YMMV. Pull requests welcome but I may/maynot merge them.

* [Sync Repositories](#sync-repos)
* [Sync Registry](#sync-registry)

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
