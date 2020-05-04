# Setup Prometheus and Grafana for WebLogic Monitoring #

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
EOF    
```
```
cat << EOF | kubectl apply -f -
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
EOF
```
```
cat << EOF | kubectl apply -f -
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
Grafana suppose to use PV and PVC but since Grafana have permission issue to use existing PVC, we will enable the persistence but instead using PV PVC it will use Oracle Block Volume.

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
      - name: node_rules
        rules:
          - alert: ClusterWarning
            for: 1m
            expr: sum by(weblogic_domainUID, weblogic_clusterName) (up{weblogic_domainUID=~'.+'}) == 1
            labels:
              severity: page
            annotations:
              description: 'Some WLS cluster has only one running server for more than 1 minutes.'
              summary: 'Some wls cluster is in warning state.'

extraScrapeConfigs: |
    - job_name: 'wls-domain1'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_label_weblogic_domainUID, __meta_kubernetes_pod_label_weblogic_clusterName]
        action: keep
        regex: default;domain1;cluster-1
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
After checking we can proceed with the installation process:
```
[opc@bastion1 prometheus]$ helm install --wait --name prometheus --namespace monitoring --values prometheus/values.yaml stable/prometheus
NAME:   prometheus
LAST DEPLOYED: Mon May  4 05:02:35 2020
NAMESPACE: monitoring
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME                     DATA  AGE
prometheus-alertmanager  1     47s
prometheus-server        5     47s

==> v1/DaemonSet
NAME                      DESIRED  CURRENT  READY  UP-TO-DATE  AVAILABLE  NODE SELECTOR  AGE
prometheus-node-exporter  3        3        3      3           3          <none>         47s

==> v1/Deployment
NAME                           READY  UP-TO-DATE  AVAILABLE  AGE
prometheus-alertmanager        1/1    1           1          47s
prometheus-kube-state-metrics  1/1    1           1          47s
prometheus-server              1/1    1           1          47s

==> v1/Pod(related)
NAME                                            READY  STATUS   RESTARTS  AGE
prometheus-alertmanager-6d95b65944-nqgs9        2/2    Running  0         47s
prometheus-kube-state-metrics-685dccc6d8-4xh2j  1/1    Running  0         47s
prometheus-node-exporter-fs4bf                  1/1    Running  0         47s
prometheus-node-exporter-mxxws                  1/1    Running  0         47s
prometheus-node-exporter-twzkf                  1/1    Running  0         47s
prometheus-server-6f549849db-6rjjf              2/2    Running  0         47s

==> v1/Service
NAME                           TYPE       CLUSTER-IP     EXTERNAL-IP  PORT(S)       AGE
prometheus-alertmanager        NodePort   10.96.9.228    <none>       80:32000/TCP  47s
prometheus-kube-state-metrics  ClusterIP  10.96.2.99     <none>       8080/TCP      47s
prometheus-node-exporter       ClusterIP  None           <none>       9100/TCP      47s
prometheus-server              NodePort   10.96.180.153  <none>       80:30000/TCP  47s

==> v1/ServiceAccount
NAME                           SECRETS  AGE
prometheus-alertmanager        1        47s
prometheus-kube-state-metrics  1        47s
prometheus-node-exporter       1        47s
prometheus-server              1        47s

==> v1beta1/ClusterRole
NAME                           AGE
prometheus-alertmanager        47s
prometheus-kube-state-metrics  47s
prometheus-server              47s

==> v1beta1/ClusterRoleBinding
NAME                           AGE
prometheus-alertmanager        47s
prometheus-kube-state-metrics  47s
prometheus-server              47s


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
[opc@bastion1 end2end]$ kubectl --namespace monitoring create secret generic grafana-secret --from-literal=username=admin --from-literal=password=welcome1
secret/grafana-secret created
[opc@bastion1 end2end]$ helm install --wait --name grafana --namespace monitoring --values grafana/values.yaml stable/grafana
NAME:   grafana
E0504 15:09:31.451763   11877 portforward.go:372] error copying from remote stream to local connection: readfrom tcp4 127.0.0.1:40145->127.0.0.1:40018: write tcp4 127.0.0.1:40145->127.0.0.1:40018: write: broken pipe
LAST DEPLOYED: Mon May  4 15:07:56 2020
NAMESPACE: monitoring
STATUS: DEPLOYED

RESOURCES:
==> v1/ClusterRole
NAME                 AGE
grafana-clusterrole  94s

==> v1/ClusterRoleBinding
NAME                        AGE
grafana-clusterrolebinding  94s

==> v1/ConfigMap
NAME          DATA  AGE
grafana       1     95s
grafana-test  1     94s

==> v1/Deployment
NAME     READY  UP-TO-DATE  AVAILABLE  AGE
grafana  1/1    1           1          94s

==> v1/PersistentVolumeClaim
NAME     STATUS  VOLUME                                                                             CAPACITY  ACCESS MODES  STORAGECLASS  AGE
grafana  Bound   ocid1.volume.oc1.phx.abyhqljsmilpogocybhd4oelhbxfq6bumxdpazshodoryj6kzbfvffstktyq  50Gi      RWO           oci           94s

==> v1/Pod(related)
NAME                     READY  STATUS   RESTARTS  AGE
grafana-96c8dc8dc-hf9wx  1/1    Running  0         94s

==> v1/Role
NAME          AGE
grafana-test  94s

==> v1/RoleBinding
NAME          AGE
grafana-test  94s

==> v1/Service
NAME     TYPE      CLUSTER-IP     EXTERNAL-IP  PORT(S)       AGE
grafana  NodePort  10.96.189.232  <none>       80:31000/TCP  94s

==> v1/ServiceAccount
NAME          SECRETS  AGE
grafana       1        94s
grafana-test  1        94s

==> v1beta1/PodSecurityPolicy
NAME          PRIV   CAPS      SELINUX   RUNASUSER  FSGROUP   SUPGROUP  READONLYROOTFS  VOLUMES
grafana       false  RunAsAny  RunAsAny  RunAsAny   RunAsAny  false     configMap,emptyDir,projected,secret,downwardAPI,persistentVolumeClaim
grafana-test  false  RunAsAny  RunAsAny  RunAsAny   RunAsAny  false     configMap,downwardAPI,emptyDir,projected,secret

==> v1beta1/Role
NAME     AGE
grafana  94s

==> v1beta1/RoleBinding
NAME     AGE
grafana  94s


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
As mentioned before using the configuration value above, it will create its own block volume to store its data:
```
[opc@bastion1 end2end]$ kubectl get pvc -n monitoring
NAME               STATUS   VOLUME                                                                              CAPACITY   ACCESS MODES   STORAGECLASS   AGE
grafana            Bound    ocid1.volume.oc1.phx.abyhqljsmilpogocybhd4oelhbxfq6bumxdpazshodoryj6kzbfvffstktyq   50Gi       RWO            oci            18m
pvc-alertmanager   Bound    pv-alertmanager                                                                     10Gi       RWO            alertmanager   10h
pvc-prometheus     Bound    pv-prometheus                                                                       10Gi       RWO            prometheus     10h
[opc@bastion1 end2end]$ kubectl get pv
NAME                                                                                CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                         STORAGECLASS   REASON   AGE
ocid1.volume.oc1.phx.abyhqljsmilpogocybhd4oelhbxfq6bumxdpazshodoryj6kzbfvffstktyq   50Gi       RWO            Delete           Bound    monitoring/grafana            oci                     18m
pv-alertmanager                                                                     10Gi       RWO            Retain           Bound    monitoring/pvc-alertmanager   alertmanager            10h
pv-prometheus                                                                       10Gi       RWO            Retain           Bound    monitoring/pvc-prometheus     prometheus              10h
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
Make sure the URL point to the correct Node IP and Node Port, then to apply this we can use this command:
```
opc@bastion1 end2end]$ curl -v -H 'Content-Type: application/json' -H "Content-Type: application/json" -X POST http://admin:welcome1@10.0.10.4:31000/api/datasources/ --data-binary @grafana/datasource.json
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
[opc@bastion1 end2end]$ curl -v -H 'Content-Type: application/json' -H "Content-Type: application/json" -X POST http://admin:welcome1@10.0.10.4:31000/api/dashboards/db --data-binary @grafana/dashboard.json
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
