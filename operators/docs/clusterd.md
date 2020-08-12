# Create Ansible Operator.

Highlevel notes

## Init 

Scaffold

```shell
mkdir welcome-php
cd welcome-php
operator-sdk init --plugins=ansible --domain example.com
```

Create your apis and kinds

```shell
operator-sdk create api --group welcome --version v1alpha1 --kind Welcome --generate-role
```

## Create Playbook

Edit the tasks file

```shell
vim roles/welcome/tasks/main.yml
```

Use the `k8s` module

```yaml
---
# tasks file for Welcome

- name: Create welcome deployment
  k8s:
    state: present
    definition: "{{ lookup('template', 'deployment.yaml.j2') }}"

- name: Create welcome service
  k8s:
    state: present
    definition: "{{ lookup('template', 'service.yaml.j2') }}"
```

Create deployment template

```shell
vim roles/welcome/templates/deployment.yaml.j2
```

Deployment template example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: "{{ ansible_operator_meta.name }}-welcome"
  name: welcome
  namespace: "{{ ansible_operator_meta.namespace }}"
spec:
  replicas: {{ instances | int }}
  selector:
    matchLabels:
      app: "{{ ansible_operator_meta.name }}-welcome"
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: "{{ ansible_operator_meta.name }}-welcome"
    spec:
      containers:
      - image: quay.io/redhatworkshops/welcome-php:latest
        name: welcome-php
        resources: {}
```

Create service teamplte

```shell
vim roles/welcome/templates/service.yaml.j2
```

Service example

```yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    app: "{{ ansible_operator_meta.name }}-welcome"
  name: "{{ ansible_operator_meta.name }}-welcome"
  namespace: "{{ ansible_operator_meta.namespace }}"
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: "{{ ansible_operator_meta.name }}-welcome"
status:
  loadBalancer: {}
```

Note `ansible_operator_meta.` prefix for the downward API

Create default values for your variables

```shell
vim roles/welcome/defaults/main.yml
```

Example `main.yml` file

```yaml
---
# defaults file for Welcome
instances: 1
```

Create sane sample CR

```shell
vim config/samples/welcome_v1alpha1_welcome.yaml
```

Sample CR

```yaml
apiVersion: welcome.example.com/v1alpha1
kind: Welcome
metadata:
  name: welcome-sample
spec:
  instances: 3
```

Configure RBAC for cluster scoped operator

```shell
vim config/rbac/role-extra.yaml
```

Sample RBAC

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: welcome-operator-user
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
- apiGroups:
  - welcome.example.com
  resources:
  - '*'
  verbs:
  - '*'
```

Add it to the kustomize file

```shell
vim config/rbac/kustomization.yaml
```

The file should look like this (note what I added)

```yaml
resources:
- role.yaml
- role_binding.yaml
- leader_election_role.yaml
- leader_election_role_binding.yaml
# Comment the following 4 lines if you want to disable
# the auth proxy (https://github.com/brancz/kube-rbac-proxy)
# which protects your /metrics endpoint.
- auth_proxy_service.yaml
- auth_proxy_role.yaml
- auth_proxy_role_binding.yaml
- auth_proxy_client_clusterrole.yaml
# Extra stuff I added - CHX
- role-extra.yaml
```

Since we're adding services, edit the `role.yaml` file to allow it from the core API group

```shell
vim config/rbac/role.yaml
```

It should look like this

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: manager-role
rules:
  ##
  ## Base operator rules
  ##
  - apiGroups:
      - ""
    resources:
      - secrets
      - services # added this - CHX
      - pods
      - pods/exec
      - pods/log
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
  - apiGroups:
      - apps
    resources:
      - deployments
      - daemonsets
      - replicasets
      - statefulsets
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
  ##
  ## Rules for welcome.example.com/v1alpha1, Kind: Welcome
  ##
  - apiGroups:
      - welcome.example.com
    resources:
      - welcomes
      - welcomes/status
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
# +kubebuilder:scaffold:rules
```

## Build the image

Login to quay

```shell
podman login quay.io
```

Build the operator image and push to Quay (in my case, the image already existed...you may need to create it)

```shell
make docker-build docker-push IMG=quay.io/christianh814/welcome-php-operator:latest
```

## Build the Operator

Export your image `IMG` var

```shell
export IMG=quay.io/christianh814/welcome-php-operator:latest
```

Set the image var for `kustomize` to use

```shell
cd config/manager && kustomize edit set image controller=${IMG} && cd ../..
```

Generate the manifest yaml

```shell
kustomize build config/default > /tmp/welcome-operator.yaml
```

## Deploy Operator

Deploy the operator (it'll end up in `$OPERATOR_NAME-system` namespace)

```shell
kustomize build config/default > /tmp/welcome-operator.yaml
```

Deploy an instance (as a regular user)

```shell
oc login -y ocp-developer
oc new-project myspace
oc create -f config/samples/welcome_v1alpha1_welcome.yaml
```
