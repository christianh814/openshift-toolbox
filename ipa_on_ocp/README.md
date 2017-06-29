# IPA On OpenShift

This assumes the following

* DNS for the domain is pointed at the OCP router
* Dynamic storage and/or a PV is available
* You have admin access to OCP

NOTE: This was tested with `oc cluster up`

## Install FreeIPA  Template

Import the community version of FreeIPA template into OpenShift to test on if you don't have an LDAP server handy.

```
oc login -u system:admin
oc create -f https://raw.githubusercontent.com/freeipa/freeipa-container/master/freeipa-server-openshift.json -n openshift
```

Next, import the image as the developer user

```
oc login -u developer
oc import-image freeipa-server:latest --from=freeipa/freeipa-server:centos-7 --confirm
```

## Deploy FreeIPA

Now that you have the template and image imported; install FreeIPA on OpenShift.

Create Service Account

```
oc project myproject
oc create serviceaccount useroot 
oc adm policy add-scc-to-user anyuid -z useroot
```

Next, login to your webconsole and create your ipa server with the following parameters, in the `myproject` project. The defaults should be fine.

![freeipa-parameters](images/freeipa-parameters.png)

Once you are sure of the parameters; click "Create"

FreeIPA generates certificates/keys for itself so you might need to generate some activity on your system, if you look at the deployment logs and see the following

```
Configuring Kerberos KDC (krb5kdc). Estimated time: 30 seconds
  [1/9]: adding kerberos container to the directory
  [2/9]: configuring KDC
  [3/9]: initialize kerberos container
WARNING: Your system is running out of entropy, you may experience long delays
```

Just run this to speed it along (run ^c after a minute or two)
```
while true; do find /; done 
```

Add the router's IP address in your `/etc/hosts` file (HINT: it's the IP address of where you ran `oc cluster up`) in order to access the fake domain you created

```
172.16.1.222	ipa.example.test
```

Login to the pod to find out the admin password

```
[root@ocp-aio]# oc get pods 
NAME                     READY     STATUS    RESTARTS   AGE
freeipa-server-1-dp1sv   1/1       Running   0          15m
sso-1-sp5ws              1/1       Running   0          1h
sso-mysql-1-3tbj7        1/1       Running   0          1h

[root@ocp-aio]# oc exec freeipa-server-1-dp1sv -- env | grep PASSWORD
PASSWORD=5YqaAHLmgXHjWvUlXarmFN7yunhXOIRS
```

Login with `username: admin` and `password: <the displayed password>`

```
firefox https://ipa.example.test
```
## Add LDAP User(s)

Fastest way is with `oc rsh`; so find out your pod name.

```
[root@ocp-aio ]# oc get pods
NAME                     READY     STATUS    RESTARTS   AGE
freeipa-server-1-dp1sv   1/1       Running   0          2h
sso-1-sp5ws              1/1       Running   0          3h
sso-mysql-1-3tbj7        1/1       Running   0          3h
```

Now `oc rsh` into this pod

```
[root@ocp-aio ]# oc rsh freeipa-server-1-dp1sv
sh-4.2#
```

Obtain a Kerberos ticket

```
sh-4.2# echo $PASSWORD | kinit admin@$(echo ${IPA_SERVER_HOSTNAME#*.} | tr '[:lower:]' '[:upper:]')
```

You should be able to show your IPA config now

```
sh-4.2# ipa config-show
  Maximum username length: 32
  Home directory base: /home
  Default shell: /bin/sh
  Default users group: ipausers
  Default e-mail domain: example.test
  Search time limit: 2
  Search size limit: 100
  User search fields: uid,givenname,sn,telephonenumber,ou,title
  Group search fields: cn,description
  Enable migration mode: FALSE
  Certificate Subject base: O=EXAMPLE.TEST
  Password Expiration Notification (days): 4
  Password plugin features: AllowNThash
  SELinux user map order: guest_u:s0$xguest_u:s0$user_u:s0$staff_u:s0-s0:c0.c1023$unconfined_u:s0-s0:c0.c1023
  Default SELinux user: unconfined_u:s0-s0:c0.c1023
  Default PAC types: nfs:NONE, MS-PAC
  IPA masters: ipa.example.test
  IPA CA servers: ipa.example.test
  IPA NTP servers: 
  IPA CA renewal master: ipa.example.test
```


Add a user now

```
sh-4.2# ipa user-add homer --first=Homer --last=Simpson --gecos="Homer J. Simposon"  --email=homerj@mailinator.com --homedir=/home/homer --password
Password: 
Enter Password again to verify: 
------------------
Added user "homer"
------------------
  User login: homer
  First name: Homer
  Last name: Simpson
  Full name: Homer Simpson
  Display name: Homer Simpson
  Initials: HS
  Home directory: /home/homer
  GECOS: Homer J. Simposon
  Login shell: /bin/sh
  Principal name: homer@EXAMPLE.TEST
  Principal alias: homer@EXAMPLE.TEST
  Email address: homerj@mailinator.com
  UID: 50800003
  GID: 50800003
  Password: True
  Member of groups: ipausers
  Kerberos keys available: True
```

You should be able to list the user's attributes

```
sh-4.2# ipa user-find homer
--------------
1 user matched
--------------
  User login: homer
  First name: Homer
  Last name: Simpson
  Home directory: /home/homer
  Login shell: /bin/sh
  Principal name: homer@EXAMPLE.TEST
  Principal alias: homer@EXAMPLE.TEST
  Email address: homerj@mailinator.com
  UID: 50800003
  GID: 50800003
  Account disabled: False
----------------------------
Number of entries returned 1
----------------------------

```

## Profit!

You should now have a full blown IPA server on OpenShift

Things to do:

* Test DNS functionality (nodePort?)
* Create Replicas
* Test cross domain trusts
* Create "bind user"

# Apendix

I created this `nodePort` config so I can run `ldapsearch` against the master.

```yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    app: freeipa-server
    template: freeipa-server
  name: freeipa-server-np
spec:
  ports:
  - name: ldap-np
    nodePort: 32389
    port: 389
    protocol: TCP
    targetPort: 389
  selector:
    deploymentconfig: freeipa-server
  sessionAffinity: None
  type: LoadBalancer
```

Now run `oc create -f freeipa-nodeport.yaml` to create the service.

Next you can run `ldapsearch` to any node in the cluster. I use the master for consistency.

```
ldapsearch -x -h ocp.chx.cloud -p 32389 -b uid=homer,cn=users,cn=accounts,dc=example,dc=test
```
