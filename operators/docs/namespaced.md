# Namespaced Scoped Operator

A "namespaced" scoped operator is an operator that will only act within a given namespace. The namespace-scoped operator (the default) watches and manages resources in a single namespace.

Namespace-scoped operators are preferred because of their flexibility. They enable decoupled upgrades, namespace isolation for failures and monitoring, and differing API definitions. 

These types of operators are useful for things that run in a cluster that don't need users creating customer resources for. An example is the prometheus operator that monitors the entire cluster.

Here are the steps to create a simple operator that deploys a hello world application

* [Create The Operator](#create-the-operator)
* [Using the K8S Module](#using-the-k8s-module)
* [Building the Operator](#building-the-operator)
* [Deplyoing the Operator](#deploying-the-operator)
* [Troubleshooting](#troubleshooting)

## Create The Operator

We create the operator with the `operator-sdk new` command

```
$ operator-sdk new welcome-operator --type=ansible --api-version=welcome.example.com/v1alpha1 --kind=Welcome
INFO[0000] Creating new Ansible operator 'welcome-operator'. 
INFO[0000] Created deploy/service_account.yaml          
INFO[0000] Created deploy/role.yaml                     
INFO[0000] Created deploy/role_binding.yaml             
INFO[0000] Created deploy/crds/welcome_v1alpha1_welcome_crd.yaml 
INFO[0000] Created deploy/crds/welcome_v1alpha1_welcome_cr.yaml 
INFO[0000] Created build/Dockerfile                     
INFO[0000] Created roles/welcome/README.md              
INFO[0000] Created roles/welcome/meta/main.yml          
INFO[0000] Created roles/welcome/files/.placeholder     
INFO[0000] Created roles/welcome/templates/.placeholder 
INFO[0000] Created roles/welcome/vars/main.yml          
INFO[0000] Created molecule/test-local/playbook.yml     
INFO[0000] Created roles/welcome/defaults/main.yml      
INFO[0000] Created roles/welcome/tasks/main.yml         
INFO[0000] Created molecule/default/molecule.yml        
INFO[0000] Created build/test-framework/Dockerfile      
INFO[0000] Created molecule/test-cluster/molecule.yml   
INFO[0000] Created molecule/default/prepare.yml         
INFO[0000] Created molecule/default/playbook.yml        
INFO[0000] Created build/test-framework/ansible-test.sh 
INFO[0000] Created molecule/default/asserts.yml         
INFO[0000] Created molecule/test-cluster/playbook.yml   
INFO[0000] Created roles/welcome/handlers/main.yml      
INFO[0000] Created watches.yaml                         
INFO[0000] Created deploy/operator.yaml                 
INFO[0000] Created .travis.yml                          
INFO[0000] Created molecule/test-local/molecule.yml     
INFO[0000] Created molecule/test-local/prepare.yml      
INFO[0000] Project creation complete.
```

This creates the scaffolding for the project

```
$ tree welcome-operator/
welcome-operator/
├── build
│   ├── Dockerfile
│   └── test-framework
│       ├── ansible-test.sh
│       └── Dockerfile
├── deploy
│   ├── crds
│   │   ├── welcome_v1alpha1_welcome_crd.yaml
│   │   └── welcome_v1alpha1_welcome_cr.yaml
│   ├── operator.yaml
│   ├── role_binding.yaml
│   ├── role.yaml
│   └── service_account.yaml
├── molecule
│   ├── default
│   │   ├── asserts.yml
│   │   ├── molecule.yml
│   │   ├── playbook.yml
│   │   └── prepare.yml
│   ├── test-cluster
│   │   ├── molecule.yml
│   │   └── playbook.yml
│   └── test-local
│       ├── molecule.yml
│       ├── playbook.yml
│       └── prepare.yml
├── roles
│   └── welcome
│       ├── defaults
│       │   └── main.yml
│       ├── files
│       ├── handlers
│       │   └── main.yml
│       ├── meta
│       │   └── main.yml
│       ├── README.md
│       ├── tasks
│       │   └── main.yml
│       ├── templates
│       └── vars
│           └── main.yml
└── watches.yaml
```

Note that `--api-version=` and `--kind` have a direct affect on how you're going to call this when you create it!

```
$ grep -i Kind welcome-operator/deploy/crds/welcome.example.com_welcomes_crd.yaml
kind: CustomResourceDefinition
    kind: Welcome
    listKind: WelcomeList

$ grep api welcome-operator/deploy/crds/welcome.example.com_v1alpha1_welcome_cr.yaml 
apiVersion: welcome.example.com/v1alpha1
```

## Using the K8S Module

Ansible has a [k8s](https://docs.ansible.com/ansible/latest/modules/k8s_module.html) module that this SDK is based on. You can see in that doc that you can use that module to manage k8s/ocp clusters. If you take a look at the `ansible-doc k8s` command you'll see this section

```yaml
- name: Read definition file from the Ansible controller file system after Jinja templating
  k8s:
    state: present
    definition: "{{ lookup('template', '/testing/deployment.yml') }}"
```

Meaning you can apply actual k8s/ocp yaml files within a playbook. Let's create some of these templates for a simple operator.

First, login to you ocp env

```
$ oc login -u developer
```

Next, create a project as a "workspace" so you can create these yamls

```
$ oc new-project workspace
$ oc project workspace
```

Make sure you're inside the operator dir

```
$ cd welcome-operator
$ ls -1
build
deploy
molecule
roles
watches.yaml
```

Create a deployment using the `oc create` command and save it to the templates dir

```
$ oc create deployment welcome \
--image=quay.io/redhatworkshops/welcome-php:latest \
--namespace REPLACEME --dry-run -o yaml > roles/welcome/templates/deployment.yaml.j2
```

Edit the `roles/welcome/templates/deployment.yaml.j2` file and templatize it

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: "{{ meta.name }}-welcome"
  name: welcome
  namespace: "{{ meta.namespace }}"
spec:
  replicas: {{ instances | int }}
  selector:
    matchLabels:
      app: "{{ meta.name }}-welcome"
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: "{{ meta.name }}-welcome"
    spec:
      containers:
      - image: quay.io/redhatworkshops/welcome-php:latest
        name: welcome-php
        resources: {}
```

Some notable changes

* `{{ meta.name }}` - Will be replaced by whatever you called the Custom Resource when you deploy it
* `{{ meta.namespace }}` - Will be replaced by the namespace you're deploying this in
* I removed the `status: {}` line (it was at the bottom)
* `"{{ instances }}"` - This will be a varaible passed by the Custom Resource on creation

Create the service yaml `roles/welcome/templates/service.yaml.j2` to look something like this

```yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    app: "{{ meta.name }}-welcome"
  name: "{{ meta.name }}-welcome"
  namespace: "{{ meta.namespace }}"
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: "{{ meta.name }}-welcome"
status:
  loadBalancer: {}
```

The same thing as before. These will be replaced by ansible on creation

Now set the default value for the `instances` variable under the `roles/welcome/defaults/main.yml` file (in case it's not set on creation)

```yaml
---
# defaults file for welcome
instances: 1
```

Next, use the `k8s` module in your playbook to apply these when someone creates a CR against this operator by editing the `roles/welcome/tasks/main.yml` file

```yaml
---
# tasks file for welcome

- name: Create welcome deployment
  k8s:
    state: present
    definition: "{{ lookup('template', 'deployment.yaml.j2') }}"

- name: Create welcome service
  k8s:
    state: present
    definition: "{{ lookup('template', 'service.yaml.j2') }}"
```

This should be enough to now build your operator

## Building the Operator

Before you build your operator, you need to login to your repository (I'm using Quay but you can use Docker Hub)

```
$ sudo docker login quay.io
Login Succeeded
```

Now run `operator-sdk build` referencing where you're going to push the image (it builds locally first)

```
$ sudo operator-sdk build quay.io/christianh814/welcome-operator:latest
INFO[0000] Building Docker image quay.io/christianh814/welcome-operator:latest 
Sending build context to Docker daemon 50.69 kB
Step 1/3 : FROM quay.io/operator-framework/ansible-operator:v0.6.0
Trying to pull repository quay.io/operator-framework/ansible-operator ... 
sha256:db7f3692cf805ceec5ea2334a0dc600d8e234b678169402316abe96a76b89bea: Pulling from quay.io/operator-framework/ansible-operator
a02a4930cb5d: Pull complete 
1bdeea372afe: Pull complete 
3b057581d180: Pull complete 
fcc78d808a3d: Pull complete 
Digest: sha256:db7f3692cf805ceec5ea2334a0dc600d8e234b678169402316abe96a76b89bea
Status: Downloaded newer image for quay.io/operator-framework/ansible-operator:v0.6.0
 ---> 5c51606d3f0e
Step 2/3 : COPY roles/ ${HOME}/roles/
 ---> 341d0486b7fa
Removing intermediate container f70d3e3f9635
Step 3/3 : COPY watches.yaml ${HOME}/watches.yaml
 ---> 9dca22e18b93
Removing intermediate container 6242bd5d5f48
Successfully built 9dca22e18b93
INFO[0074] Operator build complete.
```

Once that's built, push it to your registry

```
$ docker push quay.io/christianh814/welcome-operator:latest
```

> __**NOTE**__ If you're using Quay, you may need to login and make this image "public"

Now that your image is in a registry, edit the `deploy/operator.yaml` file and replace `"{{ REPLACE_IMAGE }}"` to your image and `"{{ pull_policy|default('Always') }}"` to `Always`. It should look something like this

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: welcome-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      name: welcome-operator
  template:
    metadata:
      labels:
        name: welcome-operator
    spec:
      serviceAccountName: welcome-operator
      containers:
        - name: welcome-operator
          # Replace this with the built image name
          image: "quay.io/christianh814/welcome-operator:latest"
          imagePullPolicy: "Always"
          volumeMounts:
          - mountPath: /tmp/ansible-operator/runner
            name: runner
          env:
            - name: WATCH_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: OPERATOR_NAME
              value: "welcome-operator"
            - name: ANSIBLE_GATHERING
              value: explicit
      volumes:
        - name: runner
          emptyDir: {}
```

Take a note of the `env` section. It's going to watch the namespace that is passed by the metadata (same with the pod names).


## Deploying the Operator

The moment of truth! Now deploy your operator! You'll need to be `system:admin` in order to deploy this operator (or anyone with `cluster-admin` privs)

```
$ oc login -u system:admin
```

Create a project 

```
$ oc new-project welcome-operator
$ oc project welcome-operator
$ oc adm policy add-scc-to-user anyuid -z welcome-operator -n welcome-operator
```

First, deploy the service account

```
$ oc create -f deploy/service_account.yaml 
serviceaccount/welcome-operator created
```

Next, create the role and the role binding

```
$ oc create -f deploy/role.yaml -f deploy/role_binding.yaml 
role.rbac.authorization.k8s.io/welcome-operator created
rolebinding.rbac.authorization.k8s.io/welcome-operator created
```

Now, create the CRD 

```
$ oc create -f deploy/crds/welcome.example.com_welcomes_crd.yaml
```

Lastly, deploy the Operator

```
$ oc create  -f deploy/operator.yaml
deployment.apps/welcome-operator created
```

After a while the operator pod should be running

```
$ oc get pods
NAME                                READY   STATUS    RESTARTS   AGE
welcome-operator-66f877b566-h5kbr   1/1     Running   0          7m31s
```

Create a custom resource under `/tmp/welcome-cr.yaml` remembering that you can define `instances` since it's a variable

```
apiVersion: welcome.example.com/v1alpha1
kind: Welcome
metadata:
  name: example-welcome
spec:
  instances: 2
```

Create this...

```
$ oc create -f /tmp/welcome-cr.yaml
```

After a while your operator will spin up the pods

```
$ oc get pods
NAME                                READY     STATUS    RESTARTS   AGE
welcome-6748ff599-5tvkg             1/1       Running   0          1m
welcome-6748ff599-ncrvp             1/1       Running   0          1m
welcome-operator-76f84cc4f6-xgkf6   2/2       Running   0          8m
```

It also created the service for you...

```
oc get svc
NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
example-welcome-welcome   ClusterIP   172.30.253.110   <none>        8080/TCP   2m
```

Let's test this; first expose the service

```
$ oc expose svc example-welcome-welcome
```

Now, curl the route to see it reply with a 200!

```
$ curl -sI http://$(oc get routes example-welcome-welcome -o jsonpath='{.spec.host}') 
HTTP/1.1 200 OK
Date: Wed, 27 Mar 2019 23:51:46 GMT
Server: Apache/2.4.27 (Red Hat) OpenSSL/1.0.1e-fips
Content-Type: text/html; charset=UTF-8
Set-Cookie: 2104e6e9ac505cf46c3eae7a47930a52=420963b15fec2b5b35b8799685dc9b12; path=/; HttpOnly
Cache-control: private
```

## Extra Credit

Given the route yaml...

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  creationTimestamp: null
  labels:
    app: example-welcome-welcome
  name: example-welcome-welcome
  namespace: REPLACEME
spec:
  host: ""
  port:
    targetPort: 8080
  to:
    kind: ""
    name: example-welcome-welcome
    weight: null
status:
  ingress: null
```

How would you have this operator create this for you?

Hints

* Any changes/additions to the ansible files needs a "re-build" of the Operator
* Remember local builds of the operator need to be pushed up to your repo

## Troubleshooting

The best way to find out what's wrong is to look at either the Ansbile/Operator pod

```
oc logs -f welcome-operator-66f877b566-h5kbr
```

You'll need to be familiar with both openshift and ansible to do the debugging
