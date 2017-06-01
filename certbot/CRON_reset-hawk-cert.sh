#!/bin/bash
hawkintcert=/root/hawkular-cert-deploy/hawkular-internal-ca.crt
hawkcert=/etc/letsencrypt/live/hawkular-metrics.apps.chx.cloud/fullchain.pem
hawkkey=/etc/letsencrypt/live/hawkular-metrics.apps.chx.cloud/privkey.pem
hawkservicename="hawkular-metrics"
url="hawkular-metrics.apps.chx.cloud"
routename="hawkular-metrics-reencrypt"
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
# Switch to the openshift-infra project
/bin/oc project openshift-infra

#
# Export the destination ca cert
/bin/oc get secrets hawkular-metrics-certificate -o jsonpath='{.data.hawkular-metrics-ca\.certificate}' | base64 -d > ${hawkintcert}
# Delete the expired route
/bin/oc delete route ${routename}

#
# Create the new route with the updated certs
/bin/oc create route reencrypt ${routename} --hostname ${url} --cert ${hawkcert} --key ${hawkkey}  --service ${hawkservicename} --dest-ca-cert ${hawkintcert}

#
# Let's come back tothe default project
/bin/oc project default
##
##
