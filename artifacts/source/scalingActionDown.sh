#!/bin/bash
# Copyright (c) 2017, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "called scalingActionDown.sh" >> scalingActionDown.log

# environment variable from admin-server pod ENV

KUBERNETES_SERVICE_HOST=10.96.0.1
KUBERNETES_SERVICE_PORT=443
INTERNAL_OPERATOR_CERT=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR5ekNDQXJPZ0F3SUJBZ0lFYkdpTVREQU5CZ2txaGtpRzl3MEJBUXNGQURBY01Sb3dHQVlEVlFRREV4RjMNClpXSnNiMmRwWXkxdmNHVnlZWFJ2Y2pBZUZ3MHlNREExTVRBd05qRTFOVE5hRncwek1EQTFNRGd3TmpFMU5UTmENCk1Cd3hHakFZQmdOVkJBTVRFWGRsWW14dloybGpMVzl3WlhKaGRHOXlNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUYNCkFBT0NBUThBTUlJQkNnS0NBUUVBcjhkei9ybFMrb2xyTEdacWdSWW1OL3crY0JaRXg4WU0wY2Z2RTY2dlcwa00NCjVja1c3LzFaS0g1SmlzTmlXWHQ4dkpWVTZhbnlBSE51WnpzMnBGT2NydVJMcld0djljK0oyTFg5WkR4N2s0WFcNCjZyR09ObkRoem40c1BCZ0crRCs3M0VMUW4zVkhoR3NwbWZua3JqdEFOSzRGczJqT0Jib0hNa0hLYWIrUTZSb0ENCmhVL2VFT21NczJEcDg1TmlTdXFlTDNVeFFURFZ2ZTJRRlhlWWdyQkl6ODJ4OWZkcXJOem5pN0toU09BbXpxOCsNCmtlL3hlYlU3OFVDMzR3MjZYWGNnVHI0RmdPTkpCaGdpZDZqUVl5V2RoTDRoZWRiUUM4dWtkaUJvak1PdFl1bE8NCmoxdUs3S2c1Z3lEcjF4cktBMlpUY01OM2NkTzFZUHVqL3BRcnNjQU45UUlEQVFBQm80SUJFekNDQVE4d0hRWUQNClZSME9CQllFRlBoaUY2ejYxaHIrYUtpN3NlSUdobGhDR0hLaU1Bc0dBMVVkRHdRRUF3SUQrRENCNEFZRFZSMFINCkJJSFlNSUhWZ2g1cGJuUmxjbTVoYkMxM1pXSnNiMmRwWXkxdmNHVnlZWFJ2Y2kxemRtT0NNMmx1ZEdWeWJtRnMNCkxYZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxYTjJZeTUzWldKc2IyZHBZeTF2Y0dWeVlYUnZjaTF1YzRJM2FXNTANClpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxXNXoNCkxuTjJZNEpGYVc1MFpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXcNClpYSmhkRzl5TFc1ekxuTjJZeTVqYkhWemRHVnlMbXh2WTJGc01BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQUENCjdzMnB5dk1FSG9lTGR6ZGN1NHk1VmtBZWdiVHlTR2MwTWUwUkR0elNBUVB6N0lCQllNLzg0R2ZkZGlmVWxwSkUNCnM1RGdmOWcxb2hzN0JBWDNZNlFOTVI3c2tDQ2o2OEUzK0RRSkpBUUUvbXhEak9mTnBvUGl3Z1QzMUcxSzdmelANCk40OUQ4Y09VZjNyTmVDaWhvREV6dDRROFlNb0RybHd6WTNzVnRDZXRLdzV3d1h1Ry9FakI2dEhwL2FXeGFSTE8NCndmMVN6RmVBTllmMDdrVkl4ZE5wbFV5RFdLYVN4VUhEYnhvM3d0YzBaQm1sU1VYNEFCZlRtOU1HZzZOcGp1ZlkNClpEOUVDNE40T2xGU0REYmpLSXBHL0Z0RTJXdHR4cHBrbGZLSDdzS3I0V1JlY2hCclBsNk9MNDVJUlFCdkVSZDkNCnhSZlNVWEJ2bFQ5Q3BHcG1ZZmN4Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K

# script parameters
scaling_action="scaleDown"
wls_domain_uid="wls-k8s-domain"
wls_cluster_name="cluster-1"
wls_domain_namespace="wls-k8s-domain-ns"
operator_service_name="internal-weblogic-operator-svc"
operator_namespace="weblogic-operator-ns"
operator_service_account="weblogic-operator-sa"
scaling_size=1
access_token=""
kubernetes_master="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"

# Parse arguments/parameters
for arg in "$@"
do
case $arg in
    --action=*)
    scaling_action="${arg#*=}"
    shift # past argument=value
    ;;
    --domain_uid=*)
    wls_domain_uid="${arg#*=}"
    shift # past argument=value
    ;;
    --cluster_name=*)
    wls_cluster_name="${arg#*=}"
    shift # past argument=value
    ;;
    --wls_domain_namespace=*)
    wls_domain_namespace="${arg#*=}"
    shift # past argument=value
    ;;
    --operator_service_name=*)
    operator_service_name="${arg#*=}"
    shift # past argument=value
    ;;
    --operator_service_account=*)
    operator_service_account="${arg#*=}"
    shift # past argument=value
    ;;
    --operator_namespace=*)
    operator_namespace="${arg#*=}"
    shift # past argument=value
    ;;
    --scaling_size=*)
    scaling_size="${arg#*=}"
    shift # past argument=value
    ;;
    --kubernetes_master=*)
    kubernetes_master="${arg#*=}"
    shift # past argument=value
    ;;
    --access_token=*)
    access_token="${arg#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

# Verify required parameters
if [ -z "$scaling_action" ] || [ -z "$wls_domain_uid" ] || [ -z "$wls_cluster_name" ]
then
    echo "Usage: scalingAction.sh --action=[scaleUp | scaleDown] --domain_uid=<domain uid> --cluster_name=<cluster name> [--kubernetes_master=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}] [--access_token=<access_token>] [--wls_domain_namespace=default] [--operator_namespace=weblogic-operator] [--operator_service_name=weblogic-operator] [--scaling_size=1]"
    echo "  where"
    echo "    action - scaleUp or scaleDown"
    echo "    domain_uid - WebLogic Domain Unique Identifier"
    echo "    cluster_name - WebLogic Cluster Name"
    echo "    kubernetes_master - Kubernetes master URL, default=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
    echo "    access_token - Service Account Bearer token for authentication and authorization for access to REST Resources"
    echo "    wls_domain_namespace - Kubernetes name space WebLogic Domain is defined in, default=default"
    echo "    operator_service_name - WebLogic Operator Service name, default=internal-weblogic-operator-svc"
    echo "    operator_service_account - Kubernetes Service Account for WebLogic Operator, default=weblogic-operator"
    echo "    operator_namespace - WebLogic Operator Namespace, default=weblogic-operator"
    echo "    scaling_size - number of WebLogic server instances by which to scale up or down, default=1"
    exit 1
fi

# Retrieve WebLogic Operator Service Account Token for Authorization
if [ -z "$access_token" ]
then
  access_token=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`
fi

echo "scaling_action: $scaling_action" >> scalingAction.log
echo "wls_domain_uid: $wls_domain_uid" >> scalingAction.log
echo "wls_cluster_name: $wls_cluster_name" >> scalingAction.log
echo "wls_domain_namespace: $wls_domain_namespace" >> scalingAction.log
echo "operator_service_name: $operator_service_name" >> scalingAction.log
echo "operator_service_account: $operator_service_account" >> scalingAction.log
echo "operator_namespace: $operator_namespace" >> scalingAction.log
echo "scaling_size: $scaling_size" >> scalingAction.log

# Query WebLogic Operator Service Port
STATUS=`curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -X GET $kubernetes_master/api/v1/namespaces/$operator_namespace/services/$operator_service_name/status` 
if [ $? -ne 0 ]
  then
    echo "Failed to retrieve status of $operator_service_name in name space: $operator_namespace" >> scalingAction.log
    echo "STATUS: $STATUS" >> scalingAction.log
    exit 1
fi

cat > cmds.py << INPUT
import sys, json
for i in json.load(sys.stdin)["spec"]["ports"]:
  if i["name"] == "rest":
    print(i["port"])
INPUT
port=`echo ${STATUS} | python cmds.py`
echo "port: $port" >> scalingAction.log

# Retrieve Custom Resource Definition for WebLogic domain
CRD=`curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -X GET $kubernetes_master/apis/apiextensions.k8s.io/v1beta1/customresourcedefinitions/domains.weblogic.oracle`
if [ $? -ne 0 ]
  then
    echo "Failed to retrieve Custom Resource Definition for WebLogic domain" >> scalingAction.log
    echo "CRD: $CRD" >> scalingAction.log
    exit 1
fi

# Find domain version
cat > cmds.py << INPUT
import sys, json
print(json.load(sys.stdin)["spec"]["version"])
INPUT
domain_api_version=`echo ${CRD} | python cmds.py`
echo "domain_api_version: $domain_api_version" >> scalingAction.log

# Reteive Custom Resource Domain 
DOMAIN=`curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" $kubernetes_master/apis/weblogic.oracle/$domain_api_version/namespaces/$wls_domain_namespace/domains/$domain_uid`
if [ $? -ne 0 ]
  then
    echo "Failed to retrieve WebLogic Domain Custom Resource Definition" >> scalingAction.log
    echo "DOMAIN: $DOMAIN" >> scalingAction.log
    exit 1
fi
echo "DOMAIN: $DOMAIN" >> scalingAction.log

# Verify if cluster is defined in clusters
cat > cmds.py << INPUT
import sys, json
outer_loop_must_break = False
for i in json.load(sys.stdin)["items"]:
  j = i["spec"]["clusters"]
  for index, cs in enumerate(j):
    if j[index]["clusterName"] == "$wls_cluster_name":
      outer_loop_must_break = True
      print True
      break
if outer_loop_must_break == False:
  print False
INPUT
in_cluster_startup=`echo ${DOMAIN} | python cmds.py`

# Retrieve replica count, of WebLogic Cluster, from Domain Custom Resource
# depending on whether the specified cluster is defined in clusters
# or not.
if [ $in_cluster_startup == "True" ]
then
  echo "$wls_cluster_name defined in clusters" >> scalingAction.log

cat > cmds.py << INPUT
import sys, json
for i in json.load(sys.stdin)["items"]:
  j = i["spec"]["clusters"]
  for index, cs in enumerate(j):
    if j[index]["clusterName"] == "$wls_cluster_name":
      print j[index]["replicas"]
INPUT
  num_ms=`echo ${DOMAIN} | python cmds.py`
else
  echo "$wls_cluster_name NOT defined in clusters" >> scalingAction.log
cat > cmds.py << INPUT
import sys, json
for i in json.load(sys.stdin)["items"]:
  print i["spec"]["replicas"]
INPUT
  num_ms=`echo ${DOMAIN} | python cmds.py`
fi
echo "current number of managed servers is $num_ms" >> scalingAction.log

# Cleanup cmds.py
[ -e cmds.py ] && rm cmds.py

# Calculate new managed server count
if [ "$scaling_action" == "scaleUp" ]
then
  # Scale up by specified scaling size 
  new_ms=$(($num_ms + $scaling_size))
else
  # Scale down by specified scaling size 
  if [ $num_ms == 1 ]
  then
    exit 0
  else
    new_ms=$(($num_ms - $scaling_size))
  fi
fi

echo "new_ms is $new_ms" >> scalingAction.log

request_body=$(cat <<EOF
{
    "managedServerCount": $new_ms 
}
EOF
)

echo "request_body: $request_body" >> scalingAction.log

content_type="Content-Type: application/json"
accept_resp_type="Accept: application/json"
requested_by="X-Requested-By: WLDF"
authorization="Authorization: Bearer $access_token"
pem_filename="weblogic_operator.pem"

# Create PEM file for Opertor SSL Certificate
if [ ${INTERNAL_OPERATOR_CERT} ]
then
  echo ${INTERNAL_OPERATOR_CERT} | base64 --decode >  $pem_filename
else
  echo "Operator Cert File not found" >> scalingAction.log
  exit 1
fi

# Operator Service REST URL for scaling
operator_url="https://$operator_service_name.$operator_namespace.svc.cluster.local:$port/operator/v1/domains/$wls_domain_uid/clusters/$wls_cluster_name/scale"
echo "operator_url: $operator_url" >> scalingAction.log

# send REST request to Operator
if [ -e $pem_filename ]
then
  result=`curl --cacert $pem_filename -X POST -H "$content_type" -H "$requested_by" -H "$authorization" -d "$request_body" $operator_url`
else
  echo "Operator PEM formatted file not found" >> scalingAction.log
  exit 1
fi

if [ $? -ne 0 ]
then
  echo "Failed scaling request to WebLogic Operator" >> scalingAction.log
  echo $result >> scalingAction.log
  exit 1
fi
echo $result >> scalingAction.log

# Cleanup generated operator PEM file
[ -e $pem_filename ] && rm $pem_filename 
