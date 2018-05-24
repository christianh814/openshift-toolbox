===== Docker Registry =====

The registry stores docker images and metadata. If you simply deploy a pod with the registry, it will use an ephemeral volume that is destroyed once the pod exits. Any images anyone has built or pushed into the registry would disappear. That would be bad.

For now we will just show how to specify the directory and leave the NFS configuration as an exercise. On the master, as root...

<code>
root@master# oadm registry \
--config=/etc/origin/master/admin.kubeconfig \
--credentials=/etc/origin/master/openshift-registry.kubeconfig \
--service-account=registry \
--images='openshift3/ose-${component}:${version}' \
--selector="region=infra" \ 
--mount-host=/registry
</code>


Wait a few moments and your registry will be up. Test with:
<code>
root@master# curl -v $(oc get services | grep registry | awk '{print $4":"$5}/v2/' | sed 's,/[^/]\+$,/v2/,')
</code>

If you have a NFS server you'd like to use...

Deploy registry without the "--mount-host" option
<code>
root@master# oadm registry \
--config=/etc/origin/master/admin.kubeconfig \
--credentials=/etc/origin/master/openshift-registry.kubeconfig \
--service-account=registry \
--images='openshift3/ose-${component}:${version}' \
--selector="region=infra" 
</code>

Then specify backend nfs storage
<code>
root@master# oc volume deploymentconfigs/docker-registry --add --overwrite --name=registry-storage --mount-path=/registry --source='{"nfs": { "server": "<fqdn>", "path": "/path/to/export"}}'</code>

use a pv
<code>
oc volume deploymentconfigs/docker-registry --add --name=registry-storage -t pvc --claim-name=registry-pvc --overwrite</code>

There are known issues when using multiple registry replicas with the same NFS volume. We recommend changing the docker-registry service’s sessionAffinity to ClientAPI like this:
<code>
root@master# oc get -o yaml svc docker-registry | \
      sed 's/\(sessionAffinity:\s*\).*/\1ClientIP/' | \
      oc replace -f -
</code>

==== Connecting To Docker Registry ====

You can connect to the docker registry hosted by OpenShift. You can do this and do "pull" and "pushes" directly into the registry. Follow the steps below to get this behavior

=== Secure Registry ===

After you [[openshift_enterprise_3.x#docker_registry|deploy the registry]] find out the service IP:PORT mapping
<code>
[root@ose3-master ~]# oc get se docker-registry
NAME              LABELS                    SELECTOR                  IP(S)            PORT(S)
docker-registry   docker-registry=default   docker-registry=default   172.30.209.118   5000/TCP
</code>

Create a server certificate for the registry service IP and the fqdn that's going to be your route (in this example it's //** docker-registry.cloudapps.example.com **//):
<code>
[root@ose3-master ~]# CA=/etc/origin/master
[root@ose3-master ~]# oadm create-server-cert --signer-cert=$CA/ca.crt --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt --hostnames='docker-registry.cloudapps.example.com,172.30.209.118' --cert=registry.crt --key=registry.key
</code>

Create the secret for the registry certificates
<code>
[root@ose3-master ~]# oc secrets new registry-secret registry.crt registry.key
</code>

Add the secret to the registry pod’s service account (i.e., the "registry" service account)
<code>
[root@ose3-master ~]# oc secrets add serviceaccounts/registry secrets/registry-secret
</code>

Create the directory where the registry will mount the keys
<code>
[root@ose3-master ~]# mkdir /registry-secrets
[root@ose3-master ~]# cp registry.crt /registry-secrets
[root@ose3-master ~]# cp registry.key /registry-secrets
</code>


Add the secret volume to the registry deployment configuration
<code>
[root@ose3-master ~]# oc volume dc/docker-registry --add --type=secret --secret-name=registry-secret -m /registry-secrets 
</code>

Enable TLS by adding the following environment variables to the registry deployment configuration
<code>
oc env dc/docker-registry REGISTRY_HTTP_TLS_CERTIFICATE=/registry-secrets/registry.crt  REGISTRY_HTTP_TLS_KEY=/registry-secrets/registry.key
</code>

Validate the registry is running in TLS mode. Wait until the // docker-registry // pod status changes to //Running// and verify the docker logs for the registry container. You should find an entry for //listening on :5000, tls//
<code>
[root@ose3-master ~]# oc get pods
NAME                      READY     STATUS    RESTARTS   AGE
docker-registry-3-yqy8v   1/1       Running   0          25s
router-1-vhjdc            1/1       Running   1          2d
[root@ose3-master ~]# oc logs docker-registry-3-yqy8v | grep tls
time="2015-08-27T16:34:56-04:00" level=info msg="listening on :5000, tls" instance.id=440700c4-16e2-4725-81c5-5835f72c7119 
</code>

Copy the CA certificate to the docker certificates directory. This must be done on all nodes in the cluster
<code>
[root@ose3-master ~]# mkdir -p /etc/docker/certs.d/172.30.209.118:5000
[root@ose3-master ~]# mkdir -p /etc/docker/certs.d/docker-registry.cloudapps.example.com:5000
[root@ose3-master ~]# cp /etc/origin/master/ca.crt /etc/docker/certs.d/172.30.209.118\:5000/
[root@ose3-master ~]# cp /etc/origin/master/ca.crt /etc/docker/certs.d/docker-registry.cloudapps.example.com\:5000/
[root@ose3-master ~]# for i in ose3-node{1..2}.example.com; do ssh ${i} mkdir -p /etc/docker/certs.d/172.30.209.118\:5000; ssh ${i} mkdir -p /etc/docker/certs.d/docker-registry.cloudapps.example.com\:5000; scp /etc/origin/master/ca.crt root@${i}:/etc/docker/certs.d/172.30.209.118\:5000/; scp /etc/origin/master/ca.crt root@${i}:/etc/docker/certs.d/docker-registry.cloudapps.example.com\:5000/; done
</code>


=== Expose Registry ===

Now expose your registry

Create a route
<code>
[root@ose3-master ~]# oc expose svc/docker-registry --hostname=docker-registry.cloudapps.example.com
</code>

Next edit the route and add the TLS termination to be "passthrough"...in the end it should look like this
<code>
[root@ose3-master ~]# oc get route/docker-registry -o yaml 
apiVersion: v1
kind: Route
metadata:
  annotations:
    openshift.io/host.generated: "false"
  creationTimestamp: 2015-08-27T20:58:16Z
  labels:
    docker-registry: default
  name: docker-registry
  namespace: default
  resourceVersion: "9557"
  selfLink: /osapi/v1beta3/namespaces/default/routes/docker-registry
  uid: 56a78ac4-4cfe-11e5-9ae1-525400baad4f
spec:
  host: docker-registry.cloudapps.example.com
  tls:
    termination: passthrough
  to:
    kind: Service
    name: docker-registry
status: {}
</code>

=== Connect to the Registry ===

Copy the CA cert to the client
<code>
[root@ose3-master ~]# scp /etc/origin/master/ca.crt 172.16.1.251:/tmp/
</code>

On the client, copy the cert into the created directory
<code>
[christian@rhel7 ~]$ sudo mkdir /etc/docker/certs.d/docker-registry.cloudapps.example.com\:5000/
[christian@rhel7 ~]$ sudo cp /tmp/ca.crt /etc/docker/certs.d/docker-registry.cloudapps.example.com\:5000/
[christian@rhel7 ~]$ sudo cp -r /etc/docker/certs.d/docker-registry.cloudapps.example.com\:5000/ /etc/docker/certs.d/docker-registry.cloudapps.example.com
[christian@rhel7 ~]$ sudo systemctl restart docker
[christian@rhel7 ~]$ sudo systemctl restart docker
</code>

Obtain a key from oc (hey that rhymed!)
<code>
[christian@rhel7 ~]$ oc whoami -t
YMQeiPbrMNxgR9mWmSzr1utX7IIJWL-QSpnlBgK8XBU
</code>

Use this key to login
<code>
[christian@rhel7 ~]$ docker login -u christian -e chernand@redhat.com -p YMQeiPbrMNxgR9mWmSzr1utX7IIJWL-QSpnlBgK8XBU docker-registry.cloudapps.example.com
WARNING: login credentials saved in /home/christian/.docker/config.json
Login Succeeded
</code>

Test it by pulling busybox to one of your projects
<code>
[christian@rhel7 ~]$ oc get projects
NAME      DISPLAY NAME        STATUS
java      Java Applications   Active
myphp     PHP Applicaitons    Active
[christian@rhel7 ~]$ docker pull busybox
[christian@rhel7 ~]$ docker tag busybox docker-registry.cloudapps.example.com/myphp/mybusybox
[christian@rhel7 ~]$ docker push  docker-registry.cloudapps.example.com/myphp/mybusybox
</code>

On the master...verify that it's in the registry
<code>
[root@ose3-master ~]# oc get is -n myphp
</code>
