#!/bin/sh

# Setup properties
ophost=10.0.10.15
opport=31001 #externalRestHttpsPort
cluster=cluster-1
size=2 #New cluster size
ns=weblogic-operator-ns # Operator NameSpace
sa=weblogic-operator-sa # Operator ServiceAccount
domainuid=wls-k8s-domain

# Retrieve service account name for given namespace
sec=`kubectl get serviceaccount ${sa} -n ${ns} -o jsonpath='{.secrets[0].name}'`
#echo "Secret [${sec}]"

# Retrieve base64 encoded secret for the given service account
enc_token=`kubectl get secret ${sec} -n ${ns} -o jsonpath='{.data.token}'`
#echo "enc_token [${enc_token}]"

# Decode the base64 encoded token
token=`echo ${enc_token} | base64 --decode`
#echo "token [${token}]"

# clean up any temporary files
rm -rf operator.rest.response.body operator.rest.stderr operator.cert.pem

# Retrieve SSL certificate from the Operator's external REST endpoint
`openssl s_client -showcerts -connect ${ophost}:${opport} </dev/null 2>/dev/null | openssl x509 -outform PEM > operator.cert.pem`

echo "Rest EndPoint url https://${ophost}:${opport}/operator/v1/domains/${domainuid}/clusters/${cluster}/scale"

# Issue 'curl' request to external REST endpoint
curl --noproxy '*' -v --cacert operator.cert.pem \
-H "Authorization: Bearer ${token}" \
-H Accept:application/json \
-H "Content-Type:application/json" \
-H "X-Requested-By:WLDF" \
-d "{\"managedServerCount\": $size}" \
-X POST  https://${ophost}:${opport}/operator/v1/domains/${domainuid}/clusters/${cluster}/scale \
-o operator.rest.response.body \
--stderr operator.rest.stderr
