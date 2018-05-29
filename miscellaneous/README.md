# Miscellaneous

These are notes where they either don't fit in any other category, or they don't warrant their own category.

**NOTE:** Some of these notes are deprecated and I only keep them here for historical purposes!

# Projects

To create a project as a user run the following command.

```
user@host$ oc new-project demo --display-name="Demo Projects" --description="Demo projects go here"
```

If you're an OSE admin and want to create a project and assign a user to it with the `--admin=${user}` command.
```
root@master# oadm new-project demo --display-name="OpenShift 3 Demo" --description="This is the first demo project with OpenShift v3" --admin=joe
```

# Create App

This is an example PHP-application you can use to test your OSEv3 environment.

Here is an example:
```
user@host$ oc new-app openshift/php~https://github.com/christianh814/php-example-ose3
```

Things to keep in mind:
  * `ose new-app` Creates a new application on OSE3
  * `openshift/php` This tells OSEv3 to use the PHP image stream provided by OSE
  * Provide the git URL for the project
    * Syntax is `imagestream~git@git:souce`

Once you created the app, start your build
```
user@host$ oc start-build php-example-ose3
```

View the build logs if you wish. Note the `-1` ...this is the build number. Find the build number with `oc get builds`
```
user@host$ oc build-logs php-example-ose3-1
```

Once the build completes; create and add your route:
```
user@host$ oc expose service php-example-ose3 --hostname=php-example.cloudapps.example.com
```


Scale up as you wish
```
user@host$ oc scale --replicas=3 dc/php-example-ose3
```

If you'd like to add another route (aka "alias"); then you need to specify a new name for it
```
user@host$ oc expose service php-example-ose3 --name=hello-openshift --hostname=hello-openshift.cloudapps.example.com
```

If you want to add SSL to your app.

```
oc create route edge --service=auth --cert=fullchain1.pem --key=privkey1.pem  --hostname=auth.myweb.io
```

Note: To see what imageStreams are available to you...
```
user@host$  oc get imageStreams -n openshift
```

Enter Container

Enter your container with the `oc rsh` command
```
user@host$  oc rsh ${podID} 
```

Create an app with a 'Dockerfile' in github
```
user@host$ oc new-app https://github.com/christianh814/ose3-ldap-auth --strategy=docker --name=auth -l appname=auth
```

Use Template for JBOSS
```
user@host$ git clone https://github.com/openshift/openshift-ansible
user@host$ cd openshift-ansible/roles/openshift_examples/files/examples/xpaas-templates/
user@host$ oc process -f eap6-basic-sti.json -v APPLICATION_NAME=ks,APPLICATION_HOSTNAME=ks.demo.sbx.osecloud.com,GIT_URI=https://github.com/RedHatWorkshops/kitchensink,GIT_REF="",GIT_CONTEXT_DIR="" | oc create -f -
```

Custom Service
```
user@host$ oc expose dc/basicauthurl --port=443 --generator=service/v1 -n auth
```
# Rolling Deployments

By default, when a new build is fired off it will stop the application while the new container is created. You can change the deployment time on an app

```
user@host$ oc edit dc/php-example-ose3
```

Change the `Strategy` to `Rolling`

# Health Checks

Readiness Probe: The kubelet uses a web hook to determine the healthiness of the container. The check is deemed successful if the hook returns with 200 or 399. 

Liveness Probe: The kubelet attempts to open a socket to the container. The container is only considered healthy if the check can establish a connection

You can add liveness/rediness probe from the cli
```
oc set probe dc/ks-stage --liveness --readiness --initial-delay-seconds=10 --timeout-seconds=60 --open-tcp=8080 
```

# Build Webhooks

You can trigger a build using the generic webhook (there is one for github too)

```
curl -i -H "Accept: application/json" -H "X-HTTP-Method-Override: PUT" -X POST \
-k https://ose3-master.example.com:8443/osapi/v1beta3/namespaces/wiring/buildconfigs/ruby-example/webhooks/secret101/generic
```

# Run Dockerhub Images

In order to run Dockerhub images you need to lift the security in your cluster so that images are not forced to run as a pre-allocated UID, without granting everyone access to the privileged SCC, you can edit the restricted SCC and change the `runAsUser` strategy:

```
root@master# oc edit scc restricted
```


...Change `runAsUser` Type to `RunAsAny`

	

**__WARING:__**This allows images to run as the root UID if no USER is specified in the Dockerfile.

Now you can pull docker images
```
user@host$ oc new-app fedora/apache --name=apache
user@host$ oc expose service apache
```

Another (better?) way
```
oc project ticketmonster-microservices
oc adm policy add-scc-to-user privileged system:serviceaccount:ticketmonster-microservices 
```

Make privileged containers by default on a project
```
oc project myproject
oc adm policy add-scc-to-user privileged -z default
```

More notes

```
oc adm policy add-scc-to-user anyuid -z default
```

Or
```
oc project myproject
oc create serviceaccount useroot
oc adm policy add-scc-to-user anyuid -z useroot
oc patch dc/myAppNeedsRoot --patch '{"spec":{"template":{"spec":{"serviceAccountName": "useroot"}}}}'
```

To let the whole project run as root...

```
oc annotate namespace myproject openshift.io/scc=privileged
```
# SSH Key For Git

Create the secret first before using the SSH key to access the private repository:
```
$ oc secrets new scmsecret ssh-privatekey=$HOME/.ssh/id_rsa
```

Add the secret to the builder service account:
```
$ oc secrets add serviceaccount/builder secrets/scmsecret
```
Add a sourceSecret field into the source section inside the buildConfig and set it to the name of the secret that you created, in this case scmsecret:
```
{
  "apiVersion": "v1",
  "kind": "BuildConfig",
  "metadata": {
    "name": "sample-build",
  },
  "parameters": {
    "output": {
      "to": {
        "name": "sample-image"
      }
    },
    "source": {
      "git": {
        "uri": "git@repository.com:user/app.git" 
      },
      "sourceSecret": {
        "name": "scmsecret"
      },
      "type": "Git"
    },
    "strategy": {
      "sourceStrategy": {
        "from": {
          "kind": "ImageStreamTag",
          "name": "python-33-centos7:latest"
        }
      },
      "type": "Source"
    }
  }
```
The URL of private repository is usually in the form `git@example.com:<username>/<repository>`

# Liveness Check for Apps

If A pod dies kubernetes will fire the pod back up.

But what if the pod is running but the application (pid) inside is hung or dead? Kubernetes needs a way to monitor the application.

This is done with a "health check" outlined [here](https://docs.openshift.com/container-platform/latest/dev_guide/application_health.html)

First edit the deploymentConfig
```
user@host$ oc edit dc/myapp -o yaml
```

Inside "containers" and just after "image" add the following
```
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 15
      timeoutSeconds: 1
```

In the end it should look something like this...

```
apiVersion: v1
kind: DeploymentConfig
metadata:
  creationTimestamp: 2015-07-30T16:15:16Z
  labels:
    appname: myapp
  name: myapp
  namespace: demo
  resourceVersion: "255603"
  selfLink: /osapi/v1beta3/namespaces/demo/deploymentconfigs/myapp
  uid: 2a7f06f8-36d6-11e5-ba31-fa163e2e3caf
spec:
  replicas: 1
  selector:
    deploymentconfig: myapp
  strategy:
    resources: {}
    type: Recreate
  template:
    metadata:
      creationTimestamp: null
      labels:
        deploymentconfig: myapp
    spec:
      containers:
      - env:
        - name: PEARSON
          value: value
        image: 172.30.182.253:5000/demo/myapp@sha256:fec918b3e488a5233b2840e1c8db7d01ee9c2b9289ca0f69b45cfea955d629b2
        imagePullPolicy: Always
        livenessProbe:
          httpGet:
            path: /info.php
            port: 8080
          initialDelaySeconds: 15
          timeoutSeconds: 1
        name: myapp
        ports:
        - containerPort: 8080
          name: myapp-tcp-8080
          protocol: TCP
        resources: {}
        securityContext:
          capabilities: {}
          privileged: false
        terminationMessagePath: /dev/termination-log
      dnsPolicy: ClusterFirst
      restartPolicy: Always
  triggers:
  - type: ConfigChange
  - imageChangeParams:
      automatic: true
      containerNames:
      - myapp
      from:
        kind: ImageStreamTag
        name: myapp:latest
      lastTriggeredImage: 172.30.182.253:5000/demo/myapp@sha256:fec918b3e488a5233b2840e1c8db7d01ee9c2b9289ca0f69b45cfea955d629b2
    type: ImageChange
status:
  details:
    causes:
    - type: ConfigChange
  latestVersion: 8

```


# REST API Notes

**NOTE: These are QND Notes!**

First get a token 
```
oc whoami -t
```

Use that token to list (GET) things
```
 curl -X GET -H "Authorization: Bearer vfNbv3DvRSyL456b1Tfy0GNoRt80tba123znqQmG6Sg" -k https://ocp.chx.cloud:8443/oapi/v1/namespaces/ks-dev/routes
```

Create a "robot" user and use that token

```
$ oc create serviceaccount robot

$ oc policy add-role-to-user admin system:serviceaccount:test:robot

$ oc describe serviceaccount robot
Name:		robot
Namespace:	test
Labels:		<none>

Image pull secrets:	robot-dockercfg-rdrpg

Mountable secrets: 	robot-token-2dsne
                   	robot-dockercfg-rdrpg

Tokens:            	robot-token-2dsne

$  oc describe secret robot-token-2dsne
Name:		robot-token-2dsne
Namespace:	test
Labels:		<none>
Annotations:	kubernetes.io/service-account.name=robot,kubernetes.io/service-account.uid=ea70e4c7-0663-11e6-b279-fa163e610e01

Type:	kubernetes.io/service-account-token

Data
===
token:		fyJhbGciOiJSUzI1NiIyInR5cCI2IkpXVCJ9...
ca.crt:		1070 bytes
namespace:	8 bytes
```

Below may be deprecated....

Do things with "POST"...fireoff a build example
```
curl -X POST  -H "Authorization: Bearer vfNbv3DvRSyL456b1Tfy0GNoRt80tba123znqQmG6Sg" -k "https://ose3-master.sandbox.osecloud.com:8443/oapi/v1/namespaces/demo/buildconfigs/myapp/instantiate" -d '{"kind":"BuildRequest","apiVersion":"v1","metadata":{"name":"myapp","creationTimestamp":null}}'
```



# RHEL Tools Pod

One time running of a RHEL pod with useful tools

```
oc run rheltest --image=registry.access.redhat.com/rhel7/rhel-tools --restart=Never --attach -i --tty
```
