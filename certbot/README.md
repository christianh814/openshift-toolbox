# Let's Encrypt

Various crons I've used to set up my SSL certs

## Hawkular

Initial Hawkular setup (done on the server that is running the router)

```
mkdir /root/hawkular-cert-deploy/
oc scale dc/router -n default --replicas=0 
certbot certonly --standalone -d hawkular-metrics.apps.chx.cloud --agree-tos -m example@example.com
```

## Kibana

Initial Kibana setup (done on the server that is running the router)

```
mkdir /root/kibana-cert-deploy/
oc scale dc/router -n default --replicas=0 
certbot certonly --standalone -d kibana.apps.chx.cloud --agree-tos -m example@example.com
```

