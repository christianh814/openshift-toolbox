# Service Mesh

These are quick and dirty notes. These notes work as of 3.11.x

## Install

These are highlevel taken from [the official doc](https://docs.openshift.com/container-platform/3.11/servicemesh-install/servicemesh-install.html#removing-bookinfo-application)

__1. Change the Kernel Params on every server__

Create the `/etc/sysctl.d/99-elasticsearch.conf` file with the following

```
vm.max_map_count = 262144
```

Then run

```
sysctl vm.max_map_count=262144
```

__2. Deploy Istio Operator__

> Note; for updated info see [this github page](https://github.com/Maistra/istio)

This repo has the operator yamls you need...load these in

```
oc new-project istio-operator
oc process -f 1.istio_community_operator_template.yaml | oc create -f -
```

Wait until the operator is up and running

```
oc logs -n istio-operator $(oc -n istio-operator get pods -l name=istio-operator --output=jsonpath={.items..metadata.name})
```

__3. Deploy the Control Plane__

Deploy the istio control plane using a customer resource for the istio CRD

```
oc create -f 2.istio-cr.yaml -n istio-operator
```

Wait until your pods come up

```
watch oc get pods -n istio-system
```

__4. Update the master config__

You need to update the master config in order to "auto inject" the envoy sidecar proxy.

Create your `/etc/origin/master/master-config.patch` file with the following contents

```yaml
admissionConfig:
  pluginConfig:
    MutatingAdmissionWebhook:
      configuration:
        apiVersion: apiserver.config.k8s.io/v1alpha1
        kubeConfigFile: /dev/null
        kind: WebhookAdmission
    ValidatingAdmissionWebhook:
      configuration:
        apiVersion: apiserver.config.k8s.io/v1alpha1
        kubeConfigFile: /dev/null
        kind: WebhookAdmission
```

Now load this into the master config file

```
cd /etc/origin/master/
cp -p master-config.yaml master-config.yaml.prepatch
oc ex config patch master-config.yaml.prepatch -p "$(cat master-config.patch)" > master-config.yaml
master-restart api && master-restart controllers
```

__5. Test__

Test with the included deployment (note that your project needs special permissions)

```
oc new-project servicemesh-test
oc project servicemesh-test
oc adm policy add-scc-to-user anyuid -z default -n servicemesh-test
oc adm policy add-scc-to-user privileged -z default -n servicemesh-test
oc create -f 3.test-deploy.yaml
```

You should see two continers in the pod. One for the app and one for envoy. Running...

```
oc get pods -l app=sleep
```

Should show the following output

> NAME                    READY     STATUS    RESTARTS   AGE
> sleep-9b989c67c-xbr6t   2/2       Running   0          14s


Delete it once it's successful

```
oc delete -f 3.test-deploy.yaml
```

## Working with Istio

WIP. You can find yamls [here](sm-resources/bookinfo)
