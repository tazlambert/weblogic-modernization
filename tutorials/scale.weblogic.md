# Manual Scaling WebLogic Cluster #

WebLogic Server supports two types of clustering configurations, configured and dynamic. Configured clusters are created by manually configuring each individual Managed Server instance. In dynamic clusters, the Managed Server configurations are generated from a single, shared template.  With dynamic clusters, when additional server capacity is needed, new server instances can be added to the cluster without having to manually configure them individually. Also, unlike configured clusters, scaling up of dynamic clusters is not restricted to the set of servers defined in the cluster but can be increased based on runtime demands.

The operator provides several ways to initiate scaling of WebLogic clusters, including:

- On-demand, updating the domain resource directly (using `kubectl`).
- Calling the operator's REST scale API, for example, from curl.
- Using a WLDF policy rule and script action to call the operator's REST scale API.
- Using a Prometheus alert action to call the operator's REST scale API.

---
Note! Do not use the console to scale the cluster. The operator controls this operation. Use the operator's options to scale your cluster deployed on Kubernetes.

---

#### Scaling WebLogic cluster using `kubectl`  ####

The easiest way to scale a WebLogic cluster in Kubernetes is to simply edit the replicas property within a domain resource.  To retain changes edit the *domain.yaml* and apply changes using `kubectl`. Use your favourite editor to open *domain.yaml*.

Find the following part:
```
clusters:
- clusterName: cluster-1
  serverStartState: "RUNNING"
  replicas: 2
```
Modify `replicas` to 3 and save changes. Apply the changes using `kubectl`:
```
kubectl apply -f /u01/domainKube.yaml
```
Check the changes in the number of pods using `kubectl`:
```
kubectl get po -n sample-domain1-ns
NAME                             READY     STATUS        RESTARTS   AGE
sample-domain1-admin-server      1/1       Running       0          57m
sample-domain1-managed-server1   1/1       Running       0          56m
sample-domain1-managed-server2   1/1       Running       0          55m
sample-domain1-managed-server3   1/1       Running       0          1m
```
Soon the managed server 3 will appear and will be ready within a few minutes. You can also check the managed server scaling action using the WebLogic Administration console:

![alt text](images/scaling/check.on.console.png)

Note! You can edit directly the existing (running) domain resource file by using the `kubectl edit` command. In this case your `domain.yaml` available on your desktop will not reflect the changes of the running domain's resource.
```
kubectl edit domain DOMAIN_UID -n DOMAIN_NAMESPACE
```
In case if you use default settings the syntax is:
```
kubectl edit domain sample-domain1 -n sample-domain1-ns
```
It will use `vi` like editor.

#### Scaling WebLogic cluster using REST API  ####

Since our WebLogic Operator already REST enabled and  already tested can list its capability by [showing the domain name](https://github.com/tazlambert/weblogic-modernization/blob/master/tutorials/deploy.weblogic.md#testing-rest-api) that have just been deployed earlier, we can also do scaling with REST API. It can be done by modifying restClient.sh script and change it scaling.sh
```
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
```
We can do the scaling by changing the size value from 2 to 4, so now we check current number of Managed Server:
```
[opc@bastion1 ~]$ kubectl get po -n wls-k8s-domain-ns -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE         NOMINATED NODE   READINESS GATES
wls-k8s-domain-admin-server      1/1     Running   0          43m   10.244.1.4   10.0.10.16   <none>           <none>
wls-k8s-domain-managed-server1   1/1     Running   0          42m   10.244.1.6   10.0.10.16   <none>           <none>
wls-k8s-domain-managed-server2   1/1     Running   0          42m   10.244.1.5   10.0.10.16   <none>           <none>
```
After we execute the scripts that already changed the size value into 4, now the number of Managed Server will be:
```
[opc@bastion1 ~]$ kubectl get po -n wls-k8s-domain-ns -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE         NOMINATED NODE   READINESS GATES
wls-k8s-domain-admin-server      1/1     Running   0          47m   10.244.1.4   10.0.10.16   <none>           <none>
wls-k8s-domain-managed-server1   1/1     Running   0          46m   10.244.1.6   10.0.10.16   <none>           <none>
wls-k8s-domain-managed-server2   1/1     Running   0          47m   10.244.1.5   10.0.10.16   <none>           <none>
wls-k8s-domain-managed-server3   1/1     Running   0          89s   10.244.1.8   10.0.10.16   <none>           <none>
wls-k8s-domain-managed-server4   1/1     Running   0          79s   10.244.1.9   10.0.10.16   <none>           <none>
```
With this REST Enabled WebLogic Operator the possibility to automate and integrate with WLDF and Prometheus are possible.
