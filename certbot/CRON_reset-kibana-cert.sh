#!/bin/bash
kibintcert=/root/kibana-cert-deploy/kibana-internal-ca.crt
kibcert=/etc/letsencrypt/live/kibana.apps.chx.cloud/fullchain.pem
kibkey=/etc/letsencrypt/live/kibana.apps.chx.cloud/privkey.pem
kibanaservicename="logging-kibana"
url="kibana.apps.chx.cloud"
routename="logging-kibana"
#
# Must run as root
[[ $(id -u) -ne 0 ]] && echo "Must be root" && exit 254

#
# Run if the week number (0-52) is divisable by 2
[[ $(( $(date +%U) % 2 )) -eq 0 ]] || exit

#
# Let's timestap this
date +%F
echo "=========="

#
# Let's be in the default project
/bin/oc project default

#
# Make sure you scale the router to 0
/bin/oc scale dc/router --replicas=0

#
# Sleep so that it gives it some time to scale down
sleep 10

#
# Renew cert if you can
/bin/certbot renew 

#
# Sleep so that it gives it some time reissue the cert
sleep 20
# Make sure you scale the router back to 1
/bin/oc scale dc/router --replicas=1

#
# Switch to the logging project
/bin/oc project logging

#
# Export the destination ca cert
/bin/oc get route -o jsonpath='{.items[*].spec.tls.destinationCACertificate}' > ${kibintcert}
# Delete the expired route
/bin/oc delete route ${routename}

#
# Create the new route with the updated certs
/bin/oc create route reencrypt ${routename} --hostname ${url} --cert ${kibcert} --key ${kibkey}  --service ${kibanaservicename} --dest-ca-cert ${kibintcert} --insecure-policy="Redirect"

#
# Let's come back tothe default project
/bin/oc project default
##
##
