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

Create a service address if there wasn't one created for you
```
user@host$ oc expose dc/basicauthurl --port=443 --generator=service/v1 -n auth
```

Expose a specific service on one port, but the container is listening on another

```
oc expose service nginx --name=exposed-svc --port=12201 --protocol="TCP" --target-port=7474 --generator="service/v2"
```
Here, service is listening on `12201` but the container is listening on `7474`

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

# Jenkins Pipelines

Quick and Dirty Jenkins notes

```
[root@ose3-master ~]# cat pipelines_notes.txt
oadm policy add-cluster-role-to-group system:build-strategy-jenkinspipeline system:authenticated

[root@ose3-master ~]# cat /etc/origin/master/pipelines.js
window.OPENSHIFT_CONSTANTS.ENABLE_TECH_PREVIEW_FEATURE.pipelines = true;

[root@ose3-master ~]# grep -B15 'pipelines.js' /etc/origin/master/master-config.yaml
assetConfig:
  logoutURL: ""
  masterPublicURL: https://ose3-master.example.com:8443
  publicURL: https://ose3-master.example.com:8443/console/
  servingInfo:
    bindAddress: 0.0.0.0:8443
    bindNetwork: tcp4
    certFile: master.server.crt
    clientCA: ""
    keyFile: master.server.key
    maxRequestsInFlight: 0
    requestTimeoutSeconds: 0
  metricsPublicURL: "https://hawkular.cloudapps.example.com/hawkular/metrics"
  loggingPublicURL: "https://kibana.cloudapps.example.com"
  extensionScripts:
  - /etc/origin/master/pipelines.js


oc create -f https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-centos7.json -n openshift
oc create -f https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/jenkins-ephemeral-template.json -n openshift
oc create -f https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/jenkins-persistent-template.json -n openshift

# as user
oc login
oc new-poroject jenkins-pipeline
oc new-app jenkins-persistent
     * With parameters:
        * Jenkins Service Name=jenkins
        * Jenkins JNLP Service Name=jenkins-jnlp
        * Jenkins Password=ovuv0M3So0U3LCgw # generated
        * Memory Limit=512Mi
        * Volume Capacity=1Gi
        * Jenkins ImageStream Namespace=openshift
        * Jenkins ImageStreamTag=jenkins:latest

oc new-app -f https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/pipeline/samplepipeline.json


# as root on master https://docs.openshift.com/container-platform/3.3/install_config/configuring_pipeline_execution.html#overview

[root@ose3-master ~]# grep -A10 jenkinsPipelineConfig /etc/origin/master/master-config.yaml
jenkinsPipelineConfig:
  autoProvisionEnabled: true
  templateNamespace: openshift
  templateName: jenkins-ephemeral
  serviceName: jenkins
  parameters: null
```
Jenkins to control different env

```
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n ks-dev
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n ks-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:ks-prod -n ks-dev
```

# Import Images

You can import images to the internal registry like so...

```
oc import-image openshift/openjdk18-openshift --from=registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift --confirm -n openshift
```

# JSON Path

Get specific items with `jsonpath`

```
oc get secrets registry-config -n default -o jsonpath='{.data.config\.yml}{"\n"}' | base64 -d
```

This is how I got route info
```
oc get route -n openshift-infra -o jsonpath='{.items[*].spec.tls.termination}{"\n"}'
```

Just do this and "follow the path"

```
oc get <resource> -o json
```

Good info [here](http://sferich888.blogspot.com/2017/01/learning-using-jsonpath-with-openshift.html)

# External Registries

Edit the buildConfig to look like

```
output:
    to:
      kind: DockerImage   
      name: docker.io/veermuchandi/mytime:latest
    pushSecret:
      name: dockerhub
```

To connect to a password protected registry...

1. First login from the command line

```
docker login myregistry.com --username=myuser --password=secret
```
2. Then create a secret referencing the fullpath of the file it created

```
oc secrets new myregistry .dockerconfigjson=/root/.docker/config.json
```
3. Finally `link` the secret to any service account you may need it for (e.g. `deployer`, `builder`, `default`, or a custom one you may have made)

```
oc secrets link deployer myregistry --for=pull
```

4. You should be able to pull that image now

```
oc new-app myregistry.com/mynamespace/myapp:latest --name=myapp
```

# ConfigMap Notes

Edit a configmap by updating the file locally and upload it via the `oc` command

```
oc create configmap test --from-file='foo=foo' --dry-run -o yaml | oc replace -f -
```

I don't know where else to put this but I created users with gogs using this...

```
curl -H "Content-Type: application/json" -X POST \
-d '{"source_id": 1, "login_name": "user-002", "username": "user-002","email": "user-002@mailinator.com"}' \
"http://gogs.redhatworkshops.io/api/v1/admin/users?token=6abd69ed8c86ee2925df7830e5c7a95197b71552"
```

A better way to do this was via shell script

```
#!/bin/bash
token="4fc0338c98cb2a36135db14a64046c4672874715"
for i in {00..99}
do
  echo "{\"source_id\": 1, \"login_name\": \"user-${i}\", \"username\": \"user-${i}\",\"email\": \"user-${i}@mailinator.com\"}" > /tmp/user-${i}.json
done

for i in {01..99}
do 
  curl -H "Content-Type: application/json" -X POST -d @/tmp/user-${i}.json \
  "http://gogs.redhatworkshops.io/api/v1/admin/users?token=${token}"
done
##
##
```
# Custom Builders

Tag customer builders in 3.7

```
oc patch is s2i-custom-python35 -p '{"spec":{"tags":[{"annotations":{"tags":"builder,python"},"name":"latest"}]}}' -n $PROJECT
```

Insecure registry
```
oc patch is jenkins -p '{"spec":{"tags":[{"importPolicy":{"insecure":true},"name":"latest"}]}}'
```

# Service Accounts

To create a `serviceaccount` for various tasks

```
oc create serviceaccount mysa -n myproject
```
Then you can get this `serviceaccount`'s token (this is a LONG LASTING TOKEN, so keep safe)

```
oc sa get-token mysa -n myproject
```

You can also, for example, give this `serviceaccount` user elevated access (let's say, for example, jenkins)

```
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:myproject:mysa
```

I think you can do it like this too

```
oc adm policy add-cluster-role-to-user cluster-admin -z mysa -n myproject
```

# Quotas

Set quotas with....

```
oc create quota myq --hard=pods=5,requests.storage=5G,persistentvolumeclaims=10 -n myproject
```

To restrict storageclasses

```
oc create quota demo-quota --hard=glusterfs-storage-block.storageclass.storage.k8s.io/persistentvolumeclaims=0,glusterfs-storage.storageclass.storage.k8s.io/requests.storage=20G
```

Format is `<storage-class-name>.storageclass.storage.k8s.io/requests.storage` and `<storage-class-name>.storageclass.storage.k8s.io/persistentvolumeclaims`

More info [found here](https://docs.openshift.com/container-platform/latest/admin_guide/quota.html)

# Post deployment hook

You can set a post deployment hook like so

```
oc set deployment-hook dc/myapp --post -- /bin/sh -c 'echo helloworld'
```
