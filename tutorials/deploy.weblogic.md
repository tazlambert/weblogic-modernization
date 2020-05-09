# Deploy WebLogic Domain to Kubernetes #

In this step we are going to deploy the WebLogic Image with Domain and Application in Pods while the logs will be placed in Persistent Volume.

![alt text](images/deploy.domain/deployDomain.png)

#### Preparing the Kubernetes cluster to run WebLogic domains ####

Create the domain namespace:
```
kubectl create namespace wls-k8s-domain-ns
```
Create a Kubernetes secret containing the Administration Server boot credentials:
```
kubectl -n wls-k8s-domain-ns create secret generic wls-k8s-domain-weblogic-credentials --from-literal=username=weblogic --from-literal=password=welcome1
```
Label the secret with domainUID:
```
kubectl label secret wls-k8s-domain-weblogic-credentials -n wls-k8s-domain-ns weblogic.domainUID=wls-k8s-domain weblogic.domainName=wls-k8s-domain
```
Create OCI image Registry secret to allow Kubernetes to pull you custome WebLogic image. Replace the registry server region code, username and auth token respectively.
WARNING!!! - be careful about username - docker-username parameter should have a value of YOUR_TENANCY_NAME/YOUR_OCIR_USERNAME - don't skip YOUR_TENANCY_NAME please.
```
kubectl create secret docker-registry ocirsecret \
  -n wls-k8s-domain-ns \
  --docker-server=YOUR_HOME_REGION_CODE.ocir.io \
  --docker-username='YOUR_TENANCY_NAME/YOUR_OCIR_USERNAME' \
  --docker-password='YOUR_OCIR_AUTH_TOKEN' \
  --docker-email='YOUR_EMAIL'
```
For example:
```
kubectl create secret docker-registry ocirsecret -n wls-k8s-domain-ns --docker-server=phx.ocir.io --docker-username='axrtkaqgdfo8/oracleidentitycloudservice/john.p.smith@testing.com' --docker-password='xxxxxxxxxx' --docker-email='john.p.smith@testing.com'
```
Now for WebLogic Domain log, it will requires its mounted directory to be in full permission mode (777) to do that we need to mount the /shared/logs to the bastion and create root folder and give 777 permission:
```
sudo mkdir /mnt/logs
sudo mount 10.0.10.9:/shared/logs /mnt/logs
sudo mkdir /mnt/logs/wls-k8s-domain
sudo chmod -Rf 777 /mnt/logs/wls-k8s-domain
```
Then now we need to create PV and PVC for this domain:
```
cd
cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-pv-pvc
mkdir output
vi create-pv-pvc-inputs.yaml
```
Edit the input file
```
# Copyright (c) 2018, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# The version of this inputs file.  Do not modify.
version: create-weblogic-sample-domain-pv-pvc-inputs-v1

# The base name of the pv and pvc
baseName: wls-k8s-domain

# Unique ID identifying a domain.
# If left empty, the generated pv can be shared by multiple domains
# This ID must not contain an underscope ("_"), and must be lowercase and unique across all domains in a Kubernetes cluster.
domainUID:

# Name of the namespace for the persistent volume claim
namespace: wls-k8s-domain-ns

# Persistent volume type for the persistent storage.
# The value must be 'HOST_PATH' or 'NFS'.
# If using 'NFS', weblogicDomainStorageNFSServer must be specified.
weblogicDomainStorageType: NFS

# The server name or ip address of the NFS server to use for the persistent storage.
# The following line must be uncomment and customized if weblogicDomainStorateType is NFS:
weblogicDomainStorageNFSServer: 10.0.10.9

# Physical path of the persistent storage.
# When weblogicDomainStorageType is set to HOST_PATH, this value should be set the to path to the
# domain storage on the Kubernetes host.
# When weblogicDomainStorageType is set to NFS, then weblogicDomainStorageNFSServer should be set
# to the IP address or name of the DNS server, and this value should be set to the exported path
# on that server.
# Note that the path where the domain is mounted in the WebLogic containers is not affected by this
# setting, that is determined when you create your domain.
# The following line must be uncomment and customized:
weblogicDomainStoragePath: /shared/logs

# Reclaim policy of the persistent storage
# The valid values are: 'Retain', 'Delete', and 'Recycle'
weblogicDomainStorageReclaimPolicy: Retain

# Total storage allocated to the persistent storage.
weblogicDomainStorageSize: 10Gi
```
After finish editing the input file then we can execute the process to create new PV n PVC for WebLogic image:
```
[opc@bastion1 create-weblogic-domain-pv-pvc]$ ./create-pv-pvc.sh -i create-pv-pvc-inputs.yaml -o output/ -e
Input parameters being used
export version="create-weblogic-sample-domain-pv-pvc-inputs-v1"
export baseName="wls-k8s-domain"
export namespace="wls-k8s-domain-ns"
export weblogicDomainStorageType="NFS"
export weblogicDomainStorageNFSServer="10.0.10.9"
export weblogicDomainStoragePath="/shared/logs"
export weblogicDomainStorageReclaimPolicy="Retain"
export weblogicDomainStorageSize="10Gi"

Generating output//pv-pvcs/wls-k8s-domain-pv.yaml
Generating output//pv-pvcs/wls-k8s-domain-pvc.yaml
Checking if the persistent volume wls-k8s-domain-pv exists
The persistent volume wls-k8s-domain-pv does not exist
Creating the persistent volume wls-k8s-domain-pv
persistentvolume/wls-k8s-domain-pv created
Checking if the persistent volume wls-k8s-domain-pv is Available
Checking if the persistent volume claim wls-k8s-domain-pvc in NameSpace wls-k8s-domain-ns exists
No resources found in wls-k8s-domain-ns namespace.
The persistent volume claim wls-k8s-domain-pvc does not exist in NameSpace wls-k8s-domain-ns
Creating the persistent volume claim wls-k8s-domain-pvc
persistentvolumeclaim/wls-k8s-domain-pvc created
Checking if the persistent volume wls-k8s-domain-pv is Bound
The following files were generated:
  output//pv-pvcs/wls-k8s-domain-pv.yaml
  output//pv-pvcs/wls-k8s-domain-pvc.yaml

Completed
```

#### Update WebLogic Operator configuration ####

Once you have your domain namespace (WebLogic domain not yet deployed) you have to update loadbalancer's and operator's configuration about where the domain will be deployed.

Make sure before execute domain `helm` install you are in the WebLogic Operator's local Git repository folder.
```
cd
cd weblogic-kubernetes-operator/
```
To update operator execute the following `helm upgrade` command:
```
helm upgrade weblogic-operator -n weblogic-operator-ns --reuse-values --set "domainNamespaces={wls-k8s-domain-ns}" --wait kubernetes/charts/weblogic-operator
```
```
Release "weblogic-operator" has been upgraded. Happy Helming!
NAME: weblogic-operator
LAST DEPLOYED: Sat May  9 14:04:51 2020
NAMESPACE: weblogic-operator-ns
STATUS: deployed
REVISION: 2
TEST SUITE: None
```
Please note the only updated parameter in this case is the domain namespace.

#### Deploy WebLogic domain on Kubernetes ####

To deploy WebLogic domain you need to create a domain resource definition which contains the necessary parameters for the operator to start the WebLogic domain properly.

You can modify the provided sample in the local repository or better if you make a copy first.
```
cp /u01/content/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/manually-create-domain/domain.yaml \
/u01/domainKube.yaml
```
Use your favourite text editor to modify domain resource definition values. If necessary remove comment leading character (#) of the parameter to activate. Always enter space before the value, after the colon.

Set the following values:

| Key | Value | Example |
|-|-|-|
|name:|wls-k8s-domain||
|namespace:|wls-k8s-domain-ns||
|weblogic.domainUID:|wls-k8s-domain||
|domainHome:|/u01/oracle/user_projects/domains/wls-k8s-domain||
|image:|YOUR_OCI_REGION_CODE.ocir.io/YOUR_TENANCY_NAME/weblogic-operator-tutorial:latest|"phx.ocir.io/johnpsmith/weblogic-modernization:latest"|
|imagePullPolicy:|"Always"||
|imagePullSecrets: <br>- name:|imagePullSecrets: <br>- name: ocirsecret||
|webLogicCredentialsSecret: <br>&nbsp;name:|webLogicCredentialsSecret: <br>&nbsp;name: wls-k8s-domain-weblogic-credentials||
|imagePullPolicy:|"Always"||
|logHomeEnabled:|true||
|logHome:|/shared/logs/wls-k8s-domain||
|volume:<br>- name:<br>- persistentVolumeClaim:<br>    claimName:|volume:<br>- name: weblogic-domain-storage-volume<br>- persistentVolumeClaim:<br>    claimName: wls-k8s-domain-pvc||
|volumeMounts:<br>- mountPath:<br>- name:|volumeMounts:<br>- mountPath: /shared/logs<br>- name: weblogic-domain-storage-volume||
|annotations:<br>- prometheus.io/scrape: |annotations:<br>- prometheus.io/scrape: false||

Your `domainKube.yaml` should be almost the same what is [available in the imported tutorial repository (click the link if you want to compare and check)](https://github.com/tazlambert/weblogic-operator-tutorial/blob/master/domainKube.yaml).

Upload domainKube.yaml to your Github repository and place it in the root directory:

![](images/deploy.domain/uploadDomainKube.png)

To deploy for the first time it can be invoked using this command in bastion:
```
kubectl apply -f domainKube.yaml
```
Check the introspector job which needs to be run first:
```
$ kubectl get pod -n wls-k8s-domain-ns
NAME                                         READY     STATUS              RESTARTS   AGE
sample-domain1-introspect-domain-job-kcn4n   0/1       ContainerCreating   0          7s
```
Check periodically the pods in the domain namespace and soon you will see the servers are starting:
```
$ kubectl get po -n wls-k8s-domain-ns -o wide
NAME                             READY     STATUS    RESTARTS   AGE       IP            NODE            NOMINATED NODE
sample-domain1-admin-server      1/1       Running   0          2m        10.244.2.10   130.61.84.41    <none>
sample-domain1-managed-server1   1/1       Running   0          1m        10.244.2.11   130.61.84.41    <none>
sample-domain1-managed-server2   0/1       Running   0          1m        10.244.1.4    130.61.52.240   <none>
```
You have to see three running pods similar to the result above. If you don't see all the running pods please wait and check periodically. The whole domain deployment may take up to 2-3 minutes depending on the compute shapes.

Beside that we can check from all the monitoring system that was craeted before from the bastion host, we can check from ELK stack especially Kibana to know if the log already being sent to the Elasticsearch or not, of course we need to create additional index pattern (wls)

![alt text](images/deploy.domain/domainKibana.png)

While for Prometheus we can check from the dashboard that we can see the metrics from WebLogic:

![alt text](images/deploy.domain/domainPrometheus.png)

And in the end all those metrics will displayed into Grafana like below:

![alt text](images/deploy.domain/domainGrafana.png)

While for the Admin Console and the test application itself it can be tested after ingress and load balancer configured
