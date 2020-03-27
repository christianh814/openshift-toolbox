# Namespaced Scoped Operator

A "clusterd" scoped operator is an operator that will act on the entire cluster. A cluster-scoped operator watches and manages resources cluster-wide

Here are the steps to create a simple operator that deploys a hello world application. This howto is an extention of the [namespaced](namespaced.md) howto..so go do that one FIRST if it's your first time creating an operator; then comeback and do this one.

> :warning: Always refer to the [upstream doc](https://github.com/operator-framework/operator-sdk/blob/master/doc/operator-scope.md#cluster-scoped-operator-usage) if you get stuck

* [Create The Operator](#create-the-operator)
* [Using the K8S Module](#using-the-k8s-module)
* [Building the Operator](#building-the-operator)
* [Deplyoing the Operator](#deploying-the-operator)
* [Troubleshooting](#troubleshooting)

## Create The Operator

We create the operator with the `operator-sdk new` command

```
$ operator-sdk new welcome-php-operator --type=ansible --api-version=welcome-php.example.com/v1alpha1 --kind=Welcomephpd
```

Now `cd` into this dir to do the remainder of this howto

```
$ cd welcome-php-operator/
```

Change `deploy/operator.yaml` so it watches all namespaces

```
$ grep -A1 WATCH_NAMESPACE deploy/operator.yaml
            - name: WATCH_NAMESPACE
              value: ""
```

Change `Role` to `ClusterRole` in the `deploy/role.yaml` file

```
$ grep ClusterRole deploy/role.yaml
kind: ClusterRole
```

And, `RoleBinding` to  `ClusterRoleBindng`, as well as `Role` to `ClusterRole` in the `deploy/role_binding.yaml` file

```
$ egrep 'ClusterRoleBinding|ClusterRole' deploy/role_binding.yaml
kind: ClusterRoleBinding
  kind: ClusterRole
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
$ oc new-project scratchspace
$ oc project scratchspace
```

Create a deployment using the `oc create` command and save it to the templates dir

```
$ oc create deployment welcome-php \
--image=quay.io/redhatworkshops/welcome-php:latest \
--namespace REPLACEME --dry-run -o yaml > roles/welcomephp/templates/deploy.yaml.j2
```

Edit the `roles/welcomephp/templates/deploy.yaml.j2` file and templatize it

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: "{{ meta.name }}-welcome-php"
  name: "{{ meta.name }}-welcome-php"
  namespace: "{{ meta.namespace }}"
spec:
  replicas: {{ instances }}
  selector:
    matchLabels:
      app: "{{ meta.name }}-welcome-php"
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: "{{ meta.name }}-welcome-php"
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

Create the service yaml `roles/welcomephp/templates/service.yaml.j2` to look something like this

```yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    app: "{{ meta.name }}-welcome-php"
  name: "{{ meta.name }}-welcome-php"
  namespace: "{{ meta.namespace }}"
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: "{{ meta.name }}-welcome-php"
status:
  loadBalancer: {}
```

The same thing as before. These will be replaced by ansible on creation

Since this is a little bit more advanced; I also created a route template `roles/welcomephp/templates/route.yaml.j2` that looks something like this

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  creationTimestamp: null
  labels:
    app: "{{ meta.name }}-welcome-php"
  name: "{{ meta.name }}-welcome-php"
  namespace: "{{ meta.namespace }}"
spec:
  host: ""
  port:
    targetPort: 8080
  to:
    kind: ""
    name: "{{ meta.name }}-welcome-php"
    weight: null
status:
  ingress: null
```

Now set the default value for the `instances` variable under the `roles/welcomephp/defaults/main.yml` file (in case it's not set on creation)

```yaml
---
# defaults file for welcomephp
instances: 1
```

Next, use the `k8s` module in your playbook by editing the `roles/welcomephp/tasks/main.yml` file

```yaml
---
# tasks file for welcomephp

- name: Create welcome-php deployment
  k8s:
    state: present
    definition: "{{ lookup('template', 'deploy.yaml.j2') }}"

- name: Create welcome-php service
  k8s:
    state: present
    definition: "{{ lookup('template', 'service.yaml.j2') }}"

- name: Create welcome-php route
  k8s:
    state: present
    definition: "{{ lookup('template', 'route.yaml.j2') }}"
```

This should be enough to now build your operator

## Building the Operator

Before you build your operator, you need to login to your repository (I'm using Quay but you can use Docker Hub)

> :warning: I'm using `podman` but you can use `docker` if you wish

```
$ podman login quay.io
Login Succeeded
```

Now run `operator-sdk build` referencing where you're going to push the image (it builds locally first)

```
$ operator-sdk build --image-builder podman quay.io/christianh814/welcome-php-operator:latest
```

Once that's built, push it to your registry

```
$ podman push quay.io/christianh814/welcome-php-operator:latest
```

> __**NOTE**__ If you're using Quay, you may need to login and make this image "public"

Now that your image is in a registry, edit the `deploy/operator.yaml` file and replace `"{{ REPLACE_IMAGE }}"` to your image and `"{{ pull_policy|default('Always') }}"` to `Always`. It should look something like this

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: welcome-php-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      name: welcome-php-operator
  template:
    metadata:
      labels:
        name: welcome-php-operator
    spec:
      serviceAccountName: welcome-php-operator
      containers:
        - name: ansible
          command:
          - /usr/local/bin/ao-logs
          - /tmp/ansible-operator/runner
          - stdout
          # Replace this with the built image name
          image: quay.io/christianh814/welcome-php-operator:latest
          imagePullPolicy: Always
          volumeMounts:
          - mountPath: /tmp/ansible-operator/runner
            name: runner
            readOnly: true
        - name: operator
          # Replace this with the built image name
          image: quay.io/christianh814/welcome-php-operator:latest
          imagePullPolicy: Always
          volumeMounts:
          - mountPath: /tmp/ansible-operator/runner
            name: runner
          env:
            - name: WATCH_NAMESPACE
              value: ""
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: OPERATOR_NAME
              value: "welcome-php-operator"
      volumes:
        - name: runner
          emptyDir: {}
```

Since we are creating a route; we need to change the `ClusterRole` to be able to modify routes. 

```yaml
- apiGroups:
  - route.openshift.io
  resources:
  - routes
  verbs:
  - create
  - update
  - delete
  - get
  - list
  - watch
  - patch
```

Also, you need to create another role that allows users to be able to create object your `apiGroup` (in this case it's `welcome-php.example.com`)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: welcome-php-operator-user
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
- apiGroups:
  - welcome-php.example.com
  resources:
  - '*'
  verbs:
  - '*'
```

The whole `deploy/role.yaml` file should look like this now

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: welcome-php-operator
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - endpoints
  - persistentvolumeclaims
  - events
  - configmaps
  - secrets
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
- apiGroups:
  - apps
  resources:
  - deployments
  - daemonsets
  - replicasets
  - statefulsets
  verbs:
  - '*'
- apiGroups:
  - monitoring.coreos.com
  resources:
  - servicemonitors
  verbs:
  - get
  - create
- apiGroups:
  - apps
  resourceNames:
  - welcome-php-operator
  resources:
  - deployments/finalizers
  verbs:
  - update
- apiGroups:
  - welcome-php.example.com
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - route.openshift.io
  resources:
  - routes
  verbs:
  - create
  - update
  - delete
  - get
  - list
  - watch
  - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: welcome-php-operator-user
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
- apiGroups:
  - welcome-php.example.com
  resources:
  - '*'
  verbs:
  - '*'
```

Edit the `deploy/role_binding.yaml` file to have the namespace you will deploy the operator on under `.subjects.namespace`. It should look like this.

```
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: welcome-php-operator
subjects:
- kind: ServiceAccount
  name: welcome-php-operator
  namespace: welcome-php-operator
roleRef:
  kind: ClusterRole
  name: welcome-php-operator
  apiGroup: rbac.authorization.k8s.io
```

Edit the `deploy/service_account.yaml` to have the namespace as well

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: welcome-php-operator
  namespace: welcome-php-operator
```

## Deploying the Operator

The moment of truth! Now deploy your operator as `system:admin` (or anyone with `cluster-admin` privs)

```
$ oc login -u system:admin
```

Create a project called `welcome-php-operator` (since that's what the operator is expecting)

```
$ oc new-project welcome-php-operator
$ oc project welcome-php-operator
```

Configure the serviceaccount, the role/rolebinding, and the CRD

```
$ oc create -f deploy/service_account.yaml \
-f deploy/role.yaml \
-f deploy/role_binding.yaml \
-f deploy/crds/welcome-php.example.com_welcomephps_crd.yaml
```

Deploy the Operator

```
$ oc create -f deploy/operator.yaml
```

After a while the operator pod should be running

```
$ oc get pods
NAME                                    READY     STATUS    RESTARTS   AGE
welcome-php-operator-6468bbbb9c-82jwv   2/2       Running   0          1m
```

Now login as `developer`

```
$ oc login -u developer
```

Create a project 

```
$ oc new-project foobar 
$ oc project foobar
```

Create a custom resource under `/tmp/welcome-php-cr.yaml` remembering that you can define `instances` since it's a variable

```yaml
apiVersion: welcome-php.example.com/v1alpha1
kind: Welcomephp
metadata:
  name: mytest
spec:
  # Add fields here
  instances: 2
```

Create this...

```
$ oc create -f /tmp/welcome-php-cr.yaml
```

After a while all your resources should come up

```
$ oc get pods
NAME                                  READY     STATUS    RESTARTS   AGE
mytest-welcome-php-6b4f4cb94c-2kf54   1/1       Running   0          41s
mytest-welcome-php-6b4f4cb94c-schqn   1/1       Running   0          41s

$ oc get svc
NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
mytest-welcome-php   ClusterIP   172.30.154.215   <none>        8080/TCP   43s

$ oc get routes
NAME                 HOST/PORT                                            PATH      SERVICES             PORT      TERMINATION   WILDCARD
mytest-welcome-php   mytest-welcome-php-foobar.apps.192.168.1.53.nip.io             mytest-welcome-php   8080                    None
```

Now, curl the route to see it reply with a 200!

```
curl -sI http://$(oc get routes mytest-welcome-php -o jsonpath='{.spec.host}')
HTTP/1.1 200 OK
Date: Thu, 28 Mar 2019 01:13:53 GMT
Server: Apache/2.4.27 (Red Hat) OpenSSL/1.0.1e-fips
Content-Type: text/html; charset=UTF-8
Set-Cookie: d9b741c3f6bd14a9da5b85bb5f483b92=c27a933f01d15e5b2e56ee58f28a9ad1; path=/; HttpOnly
Cache-control: private
```

You can list your "welcomephps" since this is a CRD

```
$ oc get welcomephps
NAME      AGE
mytest    3m
```

## Extra Credit

As `developer` (or even another user) see if you create another instance using this CR file in another project.

```
apiVersion: welcome-php.example.com/v1alpha1
kind: Welcomephp
metadata:
  name: anothertest
spec:
  instances: 1
```

Hints

* The `{.metadata.name}` needs to be unique if you're deploying multiples in the same project
* You cannote scale this app using `oc scale deploy ...` since the replica count is now handled by the CR file

## Troubleshooting

The best way to find out what's wrong is to look at either the Ansbile container or the Operator container

Ansible container...

```
$ oc logs welcome-php-operator-6468bbbb9c-82jwv -c ansible
```

Operator container...

```
$ oc logs welcome-php-operator-6468bbbb9c-82jwv -c operator
```

Ansible container has logs about the playbook run whereas the operator container has logs about operator specific tasks (also includes dump of ansible playbook runs)
