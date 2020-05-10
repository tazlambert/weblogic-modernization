#!/bin/bash
KUBERNETES_SERVER=$1
URL_TAIL=$2

REST_PORT=`kubectl get services -n weblogic-operator-ns -o jsonpath='{.items[?(@.metadata.name == "external-weblogic-operator-svc")].spec.ports[?(@.name == "rest")].nodePort}'`
REST_ADDR="https://${KUBERNETES_SERVER}:${REST_PORT}"
SECRET=`kubectl get serviceaccount weblogic-operator-sa -n weblogic-operator-ns -o jsonpath='{.secrets[0].name}'`
ENCODED_TOKEN=`kubectl get secret ${SECRET} -n weblogic-operator-ns -o jsonpath='{.data.token}'`
TOKEN=`echo ${ENCODED_TOKEN} | base64 --decode`
OPERATOR_CERT_DATA=`kubectl get secret -n weblogic-operator-ns weblogic-operator-external-rest-identity -o jsonpath='{.data.tls\.crt}'`
OPERATOR_CERT_FILE="/tmp/operator.cert.pem"
echo ${OPERATOR_CERT_DATA} | base64 --decode > ${OPERATOR_CERT_FILE}
cat ${OPERATOR_CERT_FILE}

echo "Ready to call operator REST APIs"

STATUS_CODE=`curl \
  -v \
  --cacert ${OPERATOR_CERT_FILE} \
  -H "Authorization: Bearer ${TOKEN}" \
  -H Accept:application/json \
  -X GET ${REST_ADDR}/${URL_TAIL} \
  -o curl.out \
  --stderr curl.err \
  -w "%{http_code}"`

cat curl.err
cat curl.out | jq .
