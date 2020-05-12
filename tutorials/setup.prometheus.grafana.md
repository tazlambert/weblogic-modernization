# Setup End to End Monitoring for WebLogic Domain in Kubernetes #

### Preparation  ###

#### Preparing the Oracle File Server for Oracle Kubernetes PV and PVC ####

We start from the home page of the Oracle Cloud Console, and click the burger button and direct it to File Storage and choose Mount Target that will be acted as NFS Server with its IP server that will be used further.

![alt text](images/progra/pvpvc1.png)

Click Create Mount Target

![alt text](images/progra/pvpvc2.png)

Then input the name of the desired mount target, then choose the same VCN and Subnet that the OKE and bastion resides.

![alt text](images/progra/pvpvc3.png)

The final result as below:

![alt text](images/progra/pvpvc4.png)

After Finish creating the Mount Target as the NFS Server, then we need to create the directory that will be used by creating the File System, which can be started by clicking burger menu and File Storage then click File Systems.

![alt text](images/progra/pvpvc5.png)

Click Create File System

![alt text](images/progra/pvpvc6.png)

Then input the name of the desired file system that will reflect with directory path, then choose the Mount Target that was created.

![alt text](images/progra/pvpvc7.png)

Please repeat the same process several times, in this case;
- grafana
- prometheus
- prometheus alert
- weblogic log home

![alt text](images/progra/pvpvc8.png)

#### Creating PV and PVC from Oracle File System ####

Open the access to bastion then put this command to create PV and PVC for Prometheus Alert:
```
kubectl create namespace monitoring
```
```
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-alertmanager
spec:
  storageClassName: alertmanager
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: 10.0.10.9
    path: "/shared/alert"

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-alertmanager
  namespace: monitoring

spec:
  storageClassName: alertmanager
  resources:
    requests:
      storage: 10Gi
  accessModes:
    - ReadWriteOnce
EOF
```
Next is for Prometheus PV and PVC:
```
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-prometheus
spec:
  storageClassName: prometheus
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: 10.0.10.9
    path: "/shared/prometheus"

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-prometheus
  namespace: monitoring

spec:
  storageClassName: prometheus
  resources:
    requests:
      storage: 10Gi
  accessModes:
    - ReadWriteOnce
EOF
```
Last for Grafana PV and PVC, Grafana will requires its mounted directory to be in full permission mode (777) to do that we need to mount the /shared/grafana to the bastion and create root folder and give 777 permission:
```
sudo mkdir /mnt/grafana
sudo mount 10.0.10.9:/shared/grafana /mnt/grafana
sudo mkdir /mnt/grafana/root
sudo chmod -Rf 777 /mnt/grafana/root
```
```
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-grafana

spec:
  storageClassName: grafana
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: 10.0.10.9
    path: "/shared/grafana/root"

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-grafana
  namespace: monitoring

spec:
  storageClassName: grafana
  resources:
    requests:
      storage: 10Gi
  accessModes:
    - ReadWriteOnce
EOF
```

### Setup  ###

#### Setting Up Prometheus ####
First we clone Github repo from Oracle WebLogic Monitoring Exporter:
```
cd
git clone https://github.com/oracle/weblogic-monitoring-exporter.git
cd weblogic-monitoring-exporter/samples/kubernetes/end2end/
```
Then check parameter values in prometheus/values.yaml to be like this:
```
serviceAccounts:
  pushgateway:
    create: false

pushgateway:
  enabled: false

alertmanager:
  enabled: true
  persistentVolume:
    existingClaim: pvc-alertmanager
  service:
    type: NodePort
    nodePort: 32000
  securityContext:
    runAsNonRoot: false
    runAsUser: 0

server:
  persistentVolume:
    existingClaim: pvc-prometheus
  service:
    type: NodePort
    nodePort: 30000
  securityContext:
    runAsNonRoot: false
    runAsUser: 0

alertmanagerFiles:
  alertmanager.yml:
    global:
      resolve_timeout: 5m
      #http_config:
       # proxy_url: 'http://www-proxy-hqdc.us.oracle.com:80'

    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'logging-webhook'
    receivers:
      - name: 'logging-webhook'
        webhook_configs:
        - url: 'http://webhook.webhook.svc.cluster.local:8080/log'

serverFiles:
  alerts:
    groups:
      - name: weblogic_rules
        rules:
          - alert: ClusterWarning
            for: 1m
            expr: sum by(weblogic_domainUID, weblogic_clusterName) (up{weblogic_domainUID=~'.+'}) == 1
            labels:
              severity: page
            annotations:
              description: 'Some WLS cluster has only one running server for more than 1 minutes.'
              summary: 'Some wls cluster is in warning state.'
          - alert: ScaleUpNotification
            for: 1m
            expr: sum(wls_webapp_config_open_sessions_current_count{app="testwebapp"}) > 15
            labels:
              severity: page
            annotations:
              description: 'Scale up when current sessions is greater than 15.'
              summary: 'Firing alert when total sessions active greater than 15.'
          - alert: ScaleDownNotification
            for: 1m
            expr: sum(wls_webapp_config_open_sessions_current_count{app="testwebapp"}) < 15
            labels:
              severity: page
            annotations:
              description: 'Scale up when current sessions is greater than 15.'
              summary: 'Firing alert when total sessions active greater than 15.'

extraScrapeConfigs: |
    - job_name: 'wls-k8s-domain'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_label_weblogic_domainUID, __meta_kubernetes_pod_label_weblogic_clusterName]
        action: keep
        regex: wls-k8s-domain-ns;wls-k8s-domain;cluster-1
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod_name
      basic_auth:
        username: weblogic
        password: welcome1
```
The most important part for Prometheus configuration is in extraScrapeConfigs, some value that need to change:
| Key | Value | Note |
|----------------|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| job_name | wls-k8s-domain | Use WebLogic Domain name |
| __meta_kubernetes_namespace | wls-k8s-domain-ns | Fill in regex planned WebLogic Domain Kubernetes Namespace |
| __meta_kubernetes_pod_label_weblogic_domainUID | wls-k8s-domain | Fill in regex planned WebLogic Domain Kubernetes Domain UID |
| __meta_kubernetes_pod_label_weblogic_clusterName | cluster1 | Fill in regex planned WebLogic Domain Kubernetes Cluster |
| username | weblogic | Fill WebLogic Username |
| password | welcome1 | Fill WebLogic Password |

After checking we can proceed with the installation process:
```
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
helm install --wait prometheus --namespace monitoring --values prometheus/values.yaml stable/prometheus
```
The expected result will be:
```
NAME: prometheus
LAST DEPLOYED: Sat May  9 10:16:34 2020
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-server.monitoring.svc.cluster.local


Get the Prometheus server URL by running these commands in the same shell:
  export NODE_PORT=$(kubectl get --namespace monitoring -o jsonpath="{.spec.ports[0].nodePort}" services prometheus-server)
  export NODE_IP=$(kubectl get nodes --namespace monitoring -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT


The Prometheus alertmanager can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-alertmanager.monitoring.svc.cluster.local


Get the Alertmanager URL by running these commands in the same shell:
  export NODE_PORT=$(kubectl get --namespace monitoring -o jsonpath="{.spec.ports[0].nodePort}" services prometheus-alertmanager)
  export NODE_IP=$(kubectl get nodes --namespace monitoring -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
#################################################################################
######   WARNING: Pod Security Policy has been moved to a global property.  #####
######            use .Values.podSecurityPolicy.enabled with pod-based      #####
######            annotations                                               #####
######            (e.g. .Values.nodeExporter.podSecurityPolicy.annotations) #####
#################################################################################


For more information on running Prometheus, visit:
https://prometheus.io/
```
We can check the pod and service for prometheus if already up or not:
```
[opc@bastion1 end2end]$ kubectl -n monitoring get pod -l app=prometheus
NAME                                       READY   STATUS    RESTARTS   AGE
prometheus-alertmanager-6d95b65944-nqgs9   2/2     Running   0          3m17s
prometheus-node-exporter-fs4bf             1/1     Running   0          3m17s
prometheus-node-exporter-mxxws             1/1     Running   0          3m17s
prometheus-node-exporter-twzkf             1/1     Running   0          3m17s
prometheus-server-6f549849db-6rjjf         2/2     Running   0          3m17s
```
```
[opc@bastion1 end2end]$ kubectl -n monitoring get svc -l app=prometheus
NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
prometheus-alertmanager    NodePort    10.96.9.228     <none>        80:32000/TCP   3m31s
prometheus-node-exporter   ClusterIP   None            <none>        9100/TCP       3m31s
prometheus-server          NodePort    10.96.180.153   <none>        80:30000/TCP   3m31s
```
We can check through the correct Node IP and Node Port to access the dashboard:
![alt text](images/progra/prometheus.png)

#### Setting Up Grafana ####
From the same directory we try to install Grafana by making sure if the configuration file is like below:
```
persistence:
  enabled: true
  existingClaim: pvc-grafana
service:
  type: NodePort
  port: 80
  targetPort: 3000
  nodePort: 31000
admin:
  existingSecret: "grafana-secret"
  userKey: username
  passwordKey: password
```
Then we can start the execution:
```
kubectl --namespace monitoring create secret generic grafana-secret --from-literal=username=admin --from-literal=password=welcome1
helm install --wait grafana --namespace monitoring --values grafana/values.yaml stable/grafana
```
Expected result will be:
```
NAME: grafana
LAST DEPLOYED: Sat May  9 10:22:00 2020
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
NOTES:
1. Get your 'admin' user password by running:

   kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

2. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:

   grafana.monitoring.svc.cluster.local

   Get the Grafana URL to visit by running these commands in the same shell:
export NODE_PORT=$(kubectl get --namespace monitoring -o jsonpath="{.spec.ports[0].nodePort}" services grafana)
     export NODE_IP=$(kubectl get nodes --namespace monitoring -o jsonpath="{.items[0].status.addresses[0].address}")
     echo http://$NODE_IP:$NODE_PORT


3. Login with the password from step 1 and the username: admin
```
Now we can check the available POD and Service that run in monitoring namespaces:
```
[opc@bastion1 end2end]$ kubectl get svc -n monitoring
NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
grafana                         NodePort    10.96.114.123   <none>        80:31000/TCP   18m
prometheus-alertmanager         NodePort    10.96.222.140   <none>        80:32000/TCP   21m
prometheus-kube-state-metrics   ClusterIP   10.96.53.190    <none>        8080/TCP       21m
prometheus-node-exporter        ClusterIP   None            <none>        9100/TCP       21m
prometheus-server               NodePort    10.96.20.253    <none>        80:30000/TCP   21m
```
```
[opc@bastion1 end2end]$ kubectl get po -n monitoring -o wide
NAME                                             READY   STATUS    RESTARTS   AGE   IP           NODE         NOMINATED NODE   READINESS GATES
grafana-96c8dc8dc-vxstl                          1/1     Running   0          18m   10.244.1.7   10.0.10.12   <none>           <none>
prometheus-alertmanager-6d95b65944-mxpx6         2/2     Running   0          22m   10.244.0.6   10.0.10.13   <none>           <none>
prometheus-kube-state-metrics-685dccc6d8-xpd8j   1/1     Running   0          22m   10.244.0.5   10.0.10.13   <none>           <none>
prometheus-node-exporter-46fwp                   1/1     Running   0          22m   10.0.10.12   10.0.10.12   <none>           <none>
prometheus-node-exporter-5jzzh                   1/1     Running   0          22m   10.0.10.13   10.0.10.13   <none>           <none>
prometheus-server-6f549849db-bkrx5               2/2     Running   0          22m   10.244.0.7   10.0.10.13   <none>           <none>
```
We can check through the correct Node IP and Node Port to access the dashboard:
![alt text](images/progra/grafana.png)

#### Configure Grafana connect to Prometheus ####
This will be done by creating a datasource for Grafana, this will make Prometheus as the datasource. This can be done by editing the sample file:
```
[opc@bastion1 end2end]$ more grafana/datasource.json
{
  "name":"Prometheus",
  "type":"prometheus",
  "url":"http://10.0.10.2:30000",
  "access":"proxy",
  "isDefault":true,
  "basicAuth":false
}
```
Make sure the URL point to the correct Node IP and Node Port of Prometheus Server, then to apply this we can use this command:
```
curl -v -H 'Content-Type: application/json' -H "Content-Type: application/json" -X POST http://admin:welcome1@10.0.10.4:31000/api/datasources/ --data-binary @grafana/datasource.json
```
Expected result will be:
```
* About to connect() to 10.0.10.4 port 31000 (#0)
*   Trying 10.0.10.4...
* Connected to 10.0.10.4 (10.0.10.4) port 31000 (#0)
* Server auth using Basic with user 'admin'
> POST /api/datasources/ HTTP/1.1
> Authorization: Basic YWRtaW46d2VsY29tZTE=
> User-Agent: curl/7.29.0
> Host: 10.0.10.4:31000
> Accept: */*
> Content-Type: application/json
> Content-Type: application/json
> Content-Length: 144
>
* upload completely sent off: 144 out of 144 bytes
< HTTP/1.1 200 OK
< Cache-Control: no-cache
< Content-Type: application/json
< Expires: -1
< Pragma: no-cache
< X-Frame-Options: deny
< Date: Mon, 04 May 2020 09:50:29 GMT
< Content-Length: 398
<
* Connection #0 to host 10.0.10.4 left intact
{"datasource":{"id":2,"orgId":1,"name":"Prometheus","type":"prometheus","typeLogoUrl":"","access":"proxy","url":"http://10.0.10.2:30000","password":"","user":"","database":"","basicAuth":false,"basicAuthUser":"","basicAuthPassword":"","withCredentials":false,"isDefault":true,"jsonData":{},"secureJsonFields":{},"version":1,"readOnly":false},"id":2,"message":"Datasource added","name":"Prometheus"}
```
After that we will configure the dashboard that already created to show WebLogic Metrics:
```
curl -v -H 'Content-Type: application/json' -H "Content-Type: application/json" -X POST http://admin:welcome1@10.0.10.4:31000/api/dashboards/db --data-binary @grafana/dashboard.json
```
Expected result will be:
```
* About to connect() to 10.0.10.4 port 31000 (#0)
*   Trying 10.0.10.4...
* Connected to 10.0.10.4 (10.0.10.4) port 31000 (#0)
* Server auth using Basic with user 'admin'
> POST /api/dashboards/db HTTP/1.1
> Authorization: Basic YWRtaW46d2VsY29tZTE=
> User-Agent: curl/7.29.0
> Host: 10.0.10.4:31000
> Accept: */*
> Content-Type: application/json
> Content-Type: application/json
> Content-Length: 99065
> Expect: 100-continue
>
< HTTP/1.1 100 Continue
< HTTP/1.1 200 OK
< Cache-Control: no-cache
< Content-Type: application/json
< Expires: -1
< Pragma: no-cache
< X-Frame-Options: deny
< Date: Mon, 04 May 2020 09:54:19 GMT
< Content-Length: 139
<
* Connection #0 to host 10.0.10.4 left intact
{"id":1,"slug":"weblogic-server-dashboard","status":"success","uid":"3-2eDbeZk","url":"/d/3-2eDbeZk/weblogic-server-dashboard","version":1}
```
We can try to login to Grafana dashboard and it will show this welcome page and click the WebLogic Server Dashboard;
![alt text](images/progra/grafana_welcome.png)

Since there are no WebLogic Domain deployed in the Kubernetes it will show N/A
![alt text](images/progra/grafana_dash.png)

#### Setup Webhook as Notification Receiver ####
Let's set up a simple webhook as the notification receiver. The webhook is written in a Python script which simply logs all the received notifications. Typically, webhook receivers are often used to notify systems that Alertmanager doesn’t support directly, the script will look like this:
```
# Copyright 2019, Oracle Corporation and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

import json
from http.server import BaseHTTPRequestHandler
from http.server import HTTPServer

class LogHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        print
        self.send_response(200)
        self.end_headers()
        if 'Content-Type' in self.headers and self.headers['Content-Type'] == 'application/json':
          if 'Content-Length' not in self.headers:
            print('Receiving a json request, but not an alert.')
            return
          length = int(self.headers['Content-Length'])
          data = json.loads(self.rfile.read(length).decode('utf-8'))
          for alert in data["alerts"]:
            print('!!! Receiving an alert.')
            print(json.dumps(alert, indent=2))
        else:
          print('Receiving a non-json post.')


PORT = 8080

if __name__ == '__main__':
   httpd = HTTPServer(('', PORT), LogHandler)
   print ('Webhook is serving at port', PORT)
   httpd.serve_forever()
```
Now we need to create docker image that will host the above code:
```
[opc@bastion1 end2end]$ docker build ./webhook -t webhook-log:1.0 -t phx.ocir.io/axrtkaqgdfo8/webhook-log:1.0
Sending build context to Docker daemon  6.144kB
Step 1/4 : FROM python:3.7
Trying to pull repository docker.io/library/python ...
3.7: Pulling from docker.io/library/python
90fe46dd8199: Pull complete
35a4f1977689: Pull complete
bbc37f14aded: Pull complete
74e27dc593d4: Pull complete
4352dcff7819: Pull complete
deb569b08de6: Pull complete
1aa33568be24: Pull complete
a8034acd5893: Pull complete
5ae88975c1eb: Pull complete
Digest: sha256:0032cd9c0542133c8c9dc79fb25992203b6dd2bf4c9ff9f6b5f09298061a867c
Status: Downloaded newer image for python:3.7
 ---> 84d66a048f90
Step 2/4 : WORKDIR /usr/src/app
 ---> Running in 24eab6cb6aac
Removing intermediate container 24eab6cb6aac
 ---> c7dcf0c04e38
Step 3/4 : COPY scripts/* ./
 ---> 89c3a066a327
Step 4/4 : CMD ["python", "-u", "./server.py"]
 ---> Running in 75cdd30a1656
Removing intermediate container 75cdd30a1656
 ---> ebf080d866b0
Successfully built ebf080d866b0
Successfully tagged webhook-log:1.0
Successfully tagged phx.ocir.io/axrtkaqgdfo8/webhook-log:1.0
[opc@bastion1 end2end]$ docker push phx.ocir.io/axrtkaqgdfo8/webhook-log:1.0
The push refers to repository [phx.ocir.io/axrtkaqgdfo8/webhook-log]
8027486a1048: Pushed
8a899b0b4f1a: Pushed
fc5f48f1ecdc: Pushed
86120ec29f78: Pushed
5d34cecc2826: Pushed
baf481fca4b7: Pushed
3d3e92e98337: Pushed
8967306e673e: Pushed
9794a3b3ed45: Pushed
5f77a51ade6a: Pushed
e40d297cf5f8: Pushed
1.0: digest: sha256:2179c7005923c32ba9fcf1290e3d62c008860f079823a859afd20231d75f2980 size: 2631
```
This will add new repository in the OCIR, phx.ocir.io/axrtkaqgdfo8/webhook-log, then we need to create new pod in the kubernetes, below is the yaml file:
```
# Copyright 2017, 2019, Oracle Corporation and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook
  namespace: webhook
  labels:
    app: webhook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webhook
  template:
    metadata:
      labels:
        app: webhook
    spec:
      containers:
      - image: phx.ocir.io/axrtkaqgdfo8/webhook-log:1.0
        imagePullPolicy: Always
        name: webhook
      imagePullSecrets:
      - name: ocirwebhooksecret
---
apiVersion: v1
kind: Service
metadata:
  name: webhook
  namespace: webhook
  labels:
    app: webhook
spec:
  ports:
  - port: 8080
    protocol: TCP
  selector:
    app: webhook
 ```
The value in the image parameter can be replaced with the one in the OCIR, but we need to create the secret that can access the OCIR
 ```
[opc@bastion1 end2end]$ kubectl create ns webhook
namespace/webhook created
[opc@bastion1 end2end]$ kubectl create secret docker-registry ocirwebhooksecret -n webhook --docker-server=phx.ocir.io --docker-username='axrtkaqgdfo8/oracleidentitycloudservice/john.p.smith@testing.com' --docker-password='xxxxxxx' --docker-email='john.p.smith@testing.com'
 ```
and here is the executions:
 ```
[opc@bastion1 end2end]$ kubectl apply -f ./webhook/server.yaml
deployment.apps/webhook created
service/webhook created
[opc@bastion1 end2end]$ kubectl -n webhook get pod -l app=webhook
NAME                       READY   STATUS    RESTARTS   AGE
webhook-774c7f9c47-bz85n   1/1     Running   0          2m16s
[opc@bastion1 end2end]$ kubectl -n webhook get svc -l app=webhook
NAME      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
webhook   ClusterIP   10.96.56.3   <none>        8080/TCP   2m28s
 ```
After this everything already done and can continue with WebLogic Domain deployment.
