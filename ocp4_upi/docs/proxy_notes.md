# OpenShift 4 Proxy Install

> **NOTE** This is for OCP 4.2 and newer

The only difference is that, the `install-config.yaml` file will have the proxy information. This proxy information is a "global" configuration for the cluster. Here is an example:

```yaml
apiVersion: v1
baseDomain: example.com
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ocp4
networking:
  clusterNetworks:
  - cidr: 10.254.0.0/16
    hostPrefix: 24
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
proxy:
  httpProxy: http://proxyuser:proxypass@myproxy.example.com:3128
  httpsProxy: http://proxyuser:proxypass@myproxy.example.com:3128
  noProxy: 192.168.7.0/24,10.254.0.0/16,72.30.0.0/16,example.com
pullSecret: '{"auths": ...}'
sshKey: 'ssh-ed25519 AAAA...'
```

What's important here is the `noProxy` setting. Remember to put in the range of your environemnt's network, the range of the `serviceNetwork`, and the range of the pod `clusterNetworks`. Also, add the domain of the environment you're installing in.

**NOTE** You want to put these on the "helper node" (or your bastion host) if you're using it (inside of `/etc/environment`)

```shell
root@helper# cat /etc/environment
export HTTP_PROXY="http://proxyuser:proxypass@myproxy.example.com:3128"
export HTTPS_PROXY="http://proxyuser:proxypass@myproxy.example.com:3128"
export NO_PROXY="192.168.7.0/24,10.254.0.0/16,72.30.0.0/16,.example.com"
export http_proxy="http://proxyuser:proxypass@myproxy.example.com:3128"
export https_proxy="http://proxyuser:proxypass@myproxy.example.com:3128"
export no_proxy="192.168.7.0/24,10.254.0.0/16,72.30.0.0/16,.example.com"
```
Note the leading `.` in `.example.com` ...this is a Linux thing that NEEDS to be on the bastion/helper but **NOT** in the `install-config.yaml`
