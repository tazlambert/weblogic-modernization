# Setup Auto Scaling and End to End Monitoring for WebLogic Domain in Kubernetes #

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
Do not forget to **change IP of NFS Server**
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
Next is for Prometheus PV and PVC, do not forget to **change IP of NFS Server**:
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
Do not forget to **change IP of NFS Server**
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

#### Setup Webhook as Notification Receiver and Scaling Agent ####

For this part of labs we are going to monitor http sessions of testwebapp application that we deploy to scale up or scale down and we are going to copy the original scalingAction.sh into 2 shell script; one is to scale up, scalingActionUp.sh, and one to scale down, scalingActionDown.sh. Here is the original parameter (line 7-17) that is needed to be change:
```
# script parameters
scaling_action=""
wls_domain_uid=""
wls_cluster_name=""
wls_domain_namespace="default"
operator_service_name="internal-weblogic-operator-svc"
operator_namespace="weblogic-operator"
operator_service_account="weblogic-operator"
scaling_size=1
access_token=""
kubernetes_master="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
```
The above script `scalingAction.sh`, needs **the appropriate RBAC permissions** granted for the service account user (in the namespace in which the webhook is deployed, in this case monitoring) in order to query custom Kubernetes API server for both configuration and runtime information of the domain custom resource. The following is an example YAML file for creating the appropriate Kubernetes cluster role bindings:

```
cat << EOF | kubectl apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: weblogic-domain-cluster-role
rules:
- apiGroups: ["weblogic.oracle"]
  resources: ["domains"]
  verbs: ["get", "list", "update"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: domain-cluster-rolebinding
subjects:
- kind: ServiceAccount
  name: default
  namespace: monitoring
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: weblogic-domain-cluster-role
  apiGroup: "rbac.authorization.k8s.io"
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: weblogic-domain-operator-rolebinding
  namespace: weblogic-operator-ns
subjects:
- kind: ServiceAccount
  name: default
  namespace: monitoring
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: "rbac.authorization.k8s.io"
EOF
```
For scalingActionUp.sh it will be:
```
echo "called scalingActionUp.sh" >> scalingActionUp.log

# script parameters
scaling_action="scaleUp"
wls_domain_uid="wls-k8s-domain"
wls_cluster_name="cluster-1"
wls_domain_namespace="wls-k8s-domain-ns"
operator_service_name="internal-weblogic-operator-svc"
operator_namespace="weblogic-operator-ns"
operator_service_account="weblogic-operator-sa"
scaling_size=1
access_token=""
kubernetes_master="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
```
For scalingActionDown.sh it will be:
```
echo "called scalingActionDown.sh" >> scalingActionDown.log

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
```
For those two shell script we need to get the value of INTERNAL_OPERATOR_CERT from the admin-server pod, which can be done by logging into the pod and use ENV command to show them.
```
kubectl get po -n wls-k8s-domain-ns
kubectl exec -it wls-k8s-domain-admin-server -n wls-k8s-domain-ns -- /bin/bash
env | grep INTERNAL
```
The value from there we need to put it on the webhookKube.yaml that will be used to deploy webhook docker image that will be created later:
```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    name: webhook
  name: webhook
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      name: webhook
  template:
    metadata:
      creationTimestamp: null
      labels:
         name: webhook
    spec:
      containers:
      - image: nrt.ocir.io/nr2wduco0qov/webhook:latest
        imagePullPolicy: Always
        name: webhook
        env:
        - name: INTERNAL_OPERATOR_CERT
          value: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR5ekNDQXJPZ0F3SUJBZ0lFTFdqdmp6QU5CZ2txaGtpRzl3MEJBUXNGQURBY01Sb3dHQVlEVlFRREV4RjMNClpXSnNiMmRwWXkxdmNHVnlZWFJ2Y2pBZUZ3MHlNREExTVRReE56TTRNVFphRncwek1EQTFNVEl4TnpNNE1UWmENCk1Cd3hHakFZQmdOVkJBTVRFWGRsWW14dloybGpMVzl3WlhKaGRHOXlNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUYNCkFBT0NBUThBTUlJQkNnS0NBUUVBMFE2eXdiNUpTOG1wR0tEcStCWEJYa1ZVUTRZTDdlSFptV2xCeHNNZ2loSmINCkVtRXY2bitBK25hZHY2NXBxSWcxWVN0aHVORnB0c0w1UkduZUJ2SVNmQk9XL04yZ0hHQnd3SU8zb1VzRGZQRm0NCi9SenZSczFPMmdKYTRCbEdUalc2eWxJanNodm5tUEhqNHV5aE9hbmRZcjVaM3VmRjdhMkpXaHNseUtSZ0s1ZGsNClNvcHU0WTcwQnVpN08wNTVneWlnQ3Vkd3dCM285b0NHd1g3K2lBVXZhc1VUY2I2eWt3TG14UWlyalM1dkxZLzQNCnJGOEVPc3lvb2Z2c0MrM04vZjhuNWgzYkgvMHljK05tRnl2dzczd0llZHFXVGMxbWhuNTdNcnEwTVRsZnJ4Ym8NCllLdmRCOEF3N1JTcVhoc0NKY0kwUGVRSGZYZkRKVW1GMERiMEdxVGxrUUlEQVFBQm80SUJFekNDQVE4d0hRWUQNClZSME9CQllFRkQ0bitCN2hrYWV5cHBjejF2TFpDV1A0WGxMTE1Bc0dBMVVkRHdRRUF3SUQrRENCNEFZRFZSMFINCkJJSFlNSUhWZ2g1cGJuUmxjbTVoYkMxM1pXSnNiMmRwWXkxdmNHVnlZWFJ2Y2kxemRtT0NNMmx1ZEdWeWJtRnMNCkxYZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxYTjJZeTUzWldKc2IyZHBZeTF2Y0dWeVlYUnZjaTF1YzRJM2FXNTANClpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxXNXoNCkxuTjJZNEpGYVc1MFpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXcNClpYSmhkRzl5TFc1ekxuTjJZeTVqYkhWemRHVnlMbXh2WTJGc01BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRRFANClZ1b2RycEh5Q1dpUW1Dbnd6V0tuVDFxZUtkUWhqQkdiNXA1bFJpcUZBNy9UclM1RnRhMUErMWFvZG80QUpCRTkNCkcxQ0xDQ2VTQU1DQXFldjcrejVicVdBUUhIQmh2Q2NkMTQ0bzFYNGFRUi9DNlZqUlBZQWRVejR5NzVOd3B1blMNCmhtZ1NmWDFOd0dyT3d1WkV4U2hwbHpPeFpHQ0ZLdHQ0bXEzcjlKVnVlM2txOXpvUi9DZi9lOFBEZVBWMGpDQUQNCjlOTnFsOUJQaGJLUStYZDNPak1IeWZQNDFpYzVNUk1DK09iRUE1VnJhRmlkRHpta0V3cUxqbElJZmpSQ3ZyRloNCmlwZ2hGRUZ2cEJ6WUhsckRwVUxLWUZveTdUeDRCQy93dVFwN0RJaGJrbHR4bWQyRU9nczcya3R3elRzK0EvcnYNCmN5V3FObnIxWS9LTzJvN1JTSkh3Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
        ports:
        - containerPort: 9000
          protocol: TCP
        resources:
          limits:
            cpu: 500m
            memory: 2500Mi
          requests:
            cpu: 100m
            memory: 100Mi
      imagePullSecrets:
      - name: ocirwebhooksecret
      restartPolicy: Always
      securityContext: {}
      terminationGracePeriodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: webhook
  namespace: monitoring
spec:
  selector:
    name: webhook
  type: ClusterIP
  ports:
  - port: 9000
```
Let's set up a simple webhook from this [repo](https://github.com/bhabermaas/kubernetes-projects) download the [webhook](https://github.com/bhabermaas/kubernetes-projects/raw/master/apps/webhook) then do these:
```
cd
mkdir -p webhook/apps
mkdir -p webhook/scripts
mkdir -p webhook/webhooks
cd webhook
```
Put the downloaded webhook file to webhook/apps, webhookKube.yaml to webhook, scalingActionUp.sh to webhook/scripts, scalingActionDown.sh to webhook/scripts, then we need to create hooks.json that will be put inside webhook/webhooks:
```
[
  {
    "id": "scaleup",
    "execute-command": "/var/scripts/scalingActionUp.sh",
    "command-working-directory": "/var/scripts",
    "response-message": "scale-up call ok\n"
  },
  { "id": "scaledown",
    "execute-command": "/var/scripts/scalingActionDown.sh",
    "command-working-directory": "/var/scripts",
    "response-message": "scale-down call ok\n"
  }
]
```
Also we need to create the docker file to build the image that will be placed in the webhook:
```
FROM store/oracle/serverjre:8

COPY apps/webhook /bin/webhook
COPY webhooks/hooks.json /etc/webhook/
COPY scripts/scalingActionUp.sh /var/scripts/
COPY scripts/scalingActionDown.sh /var/scripts/
RUN chmod 755 /var/scripts/*
CMD ["-verbose", "-hooks=/etc/webhook/hooks.json", "-hotreload"]
ENTRYPOINT ["/bin/webhook"]
```
The final look of the webhook directory will look like this:
```
[opc@bastion1 webhook]$ find . -type f -printf "%p\n"
./apps/webhook
./webhooks/hooks.json
./scripts/scalingActionUp.sh
./scripts/scalingActionDown.sh
./webhookKube.yaml
./Dockerfile.webhook
```
Now we need to create docker image that will host the above code, we need to logout from OCIR and login to Docker Hub then later login back to OCIR:
```
cd
cd webhook
docker logout
docker login
docker build -t phx.ocir.io/axrtkaqgdfo8/webhook:latest -f Dockerfile.webhook .
docker login phx.ocir.io -u axrtkaqgdfo8/oracleidentitycloudservice/john.p.smith@testing.com
docker push phx.ocir.io/axrtkaqgdfo8/webhook:latest
```
Before applying the webhookKube.yaml we need to create scret to access webhook repo in OCIR:
```
kubectl create secret docker-registry ocirwebhooksecret -n monitoring --docker-server=nrt.ocir.io --docker-username='nr2wduco0qov/oracleidentitycloudservice/john.p.smith@testing.com' --docker-password='take-from-the-same-ocir-weblogic' --docker-email='john.p.smith@testing.com'
```
This will add new repository in the OCIR, phx.ocir.io/axrtkaqgdfo8/webhook, then we need to create new pod in the kubernetes, below is the yaml file and here is the executions:
 ```
kubectl apply -f webhookKube.yaml
```
Check the POD and Service that being deployed:
```
[opc@bastion1 webhook]$ kubectl get po -n monitoring -o wide
NAME                                             READY   STATUS    RESTARTS   AGE     IP            NODE        NOMINATED NODE   READINESS GATES
webhook-7c6d986484-vrdn5                         1/1     Running   0          84m     10.244.1.20   10.0.10.8   <none>           <none>

[opc@bastion1 webhook]$ kubectl get svc -n monitoring
NAME                            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
webhook                         ClusterIP   10.96.84.144   <none>        9000/TCP       85m
```
Above service can called from inside OKE cluster using nameservice as explained in [this article](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/):
```
http://webhook.monitoring.svc.cluster.local:9000/hooks/scaleup
http://webhook.monitoring.svc.cluster.local:9000/hooks/scaledown
```
#### Setting Up Prometheus ####
First we clone Github repo from Oracle WebLogic Monitoring Exporter:
```
cd
git clone https://github.com/oracle/weblogic-monitoring-exporter.git
cd weblogic-monitoring-exporter/samples/kubernetes/end2end/
```
Then check parameter values in prometheus/values.yaml to be like the one in this [repo](https://github.com/tazlambert/weblogic-modernization/blob/master/artifacts/source/prometheusValues.yaml), it can be divided into 3 parts, first is for prometheus alertmanager on what to do if alert is received, for this labs we call webhook service that we created above:
```
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
      receiver: 'web.hook.scaleup'
      routes:
      - match:
          alertname: ScaleUpNotification
        receiver: web.hook.scaleup
      - match:
          alertname: ScaleDownNotification
        receiver: web.hook.scaledown
    receivers:
    - name: 'web.hook.scaleup'
      webhook_configs:
      - url: 'http://webhook.monitoring.svc.cluster.local:9000/hooks/scaleup'
    - name: 'web.hook.scaledown'
      webhook_configs:
      - url: 'http://webhook.monitoring.svc.cluster.local:9000/hooks/scaledown'
    inhibit_rules:
      - source_match:
          severity: 'critical'
        target_match:
          severity: 'warning'
        equal: ['alertname', 'dev', 'instance']
```
Below is the second part where prometheus will evaluate the metrics that we define here to trigger alert to be sent to alertmanager, in this the alert is if web open sessions current count is more than 15:
```
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
              description: 'Scale down when current sessions is less than 15.'
              summary: 'Firing alert when total sessions active less than 15.'
```
The last part is the configuration to gather which WebLogic doamin where the metrics will be used for the prometheus above:
```
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
  "url":"http://10.0.10.13:30000",
  "access":"proxy",
  "isDefault":true,
  "basicAuth":false
}
```
Make sure the URL point to the correct Node IP and Node Port of Prometheus Server, then to apply this we can use this command, please do not forget to **change the IP address of grafana**:
```
curl -v -H 'Content-Type: application/json' -H "Content-Type: application/json" -X POST http://admin:welcome1@10.0.10.12:31000/api/datasources/ --data-binary @grafana/datasource.json
```
Expected result will be:
```
* About to connect() to 10.0.10.12 port 31000 (#0)
*   Trying 10.0.10.12...
* Connected to 10.0.10.12 (10.0.10.12) port 31000 (#0)
* Server auth using Basic with user 'admin'
> POST /api/datasources/ HTTP/1.1
> Authorization: Basic YWRtaW46d2VsY29tZTE=
> User-Agent: curl/7.29.0
> Host: 10.0.10.12:31000
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
* Connection #0 to host 10.0.10.12 left intact
{"datasource":{"id":2,"orgId":1,"name":"Prometheus","type":"prometheus","typeLogoUrl":"","access":"proxy","url":"http://10.0.10.12:30000","password":"","user":"","database":"","basicAuth":false,"basicAuthUser":"","basicAuthPassword":"","withCredentials":false,"isDefault":true,"jsonData":{},"secureJsonFields":{},"version":1,"readOnly":false},"id":2,"message":"Datasource added","name":"Prometheus"}
```
After that we will configure the dashboard that already created to show WebLogic Metrics:
```
curl -v -H 'Content-Type: application/json' -H "Content-Type: application/json" -X POST http://admin:welcome1@10.0.10.12:31000/api/dashboards/db --data-binary @grafana/dashboard.json
```
Expected result will be:
```
* About to connect() to 10.0.10.12 port 31000 (#0)
*   Trying 10.0.10.12...
* Connected to 10.0.10.12 (10.0.10.12) port 31000 (#0)
* Server auth using Basic with user 'admin'
> POST /api/dashboards/db HTTP/1.1
> Authorization: Basic YWRtaW46d2VsY29tZTE=
> User-Agent: curl/7.29.0
> Host: 10.0.10.12:31000
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
* Connection #0 to host 10.0.10.12 left intact
{"id":1,"slug":"weblogic-server-dashboard","status":"success","uid":"3-2eDbeZk","url":"/d/3-2eDbeZk/weblogic-server-dashboard","version":1}
```

#### Testing Monitoring Tools ####

Now we can check from all the monitoring system that was craeted before from the bastion host, we can check from ELK stack especially Kibana to know if the log already being sent to the Elasticsearch or not, of course we need to [create additional index pattern](https://github.com/tazlambert/weblogic-modernization/blob/master/tutorials/setup.wko.md#elk-log-index-creation) (wls)

![alt text](images/deploy.domain/domainKibana.png)

While for Prometheus we can check from the dashboard that we can see the metrics from WebLogic:

![alt text](images/deploy.domain/domainPrometheus.png)

And in the end all those metrics will displayed into Grafana like below:

![alt text](images/deploy.domain/domainGrafana.png)

While for the Admin Console and the test application itself it can be tested after ingress and load balancer configured

#### Testing Auto Scaling ####

To test it we need to create simple shell script loadTest.sh using curl to access the load balancer:
```
#!/bin/bash

COUNTER=0
MAXCURL=17
while [ $COUNTER -lt $MAXCURL ]; do
OUTPUT="$(curl http://$1/opdemo/)"
if [ "$OUTPUT" != "404 page not found" ]; then
echo $OUTPUT
let COUNTER=COUNTER+1
sleep 1
fi
done
```
Get the load balancer EXTERNAL-IP address using:
```
kubectl get svc -n ingress-nginx
```
Then we can run the loadTest.sh script:
```
./loadTest.sh 168.138.219.15
```
It will show repeatedly this:
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   368  100   368    0     0    187      0  0:00:01  0:00:01 --:--:--   187
<!DOCTYPE html> <html> <body> <h1>WebLogic Operator Demo App - MBean properties: ???</h1><br> <b>Server time:</b> 04:26:00<br><b>Hostname:</b> wls-k8s-domain-managed-server2<br><h2>Datasource properties</h2> <p><font color="red">No datasource name provided.</font><br><font color="red">Append ?dsname=YOUR_DATA_SOURCE_NAME to the URL.</font></p> </body> </html>
```
Now the number of pod or MS for this domain show:
```
NAME                             READY   STATUS    RESTARTS   AGE
wls-k8s-domain-admin-server      1/1     Running   0          78m
wls-k8s-domain-managed-server1   1/1     Running   0          77m
wls-k8s-domain-managed-server2   1/1     Running   0          23m
```
Now try to hit loadTest.sh several times, and we can see the traffic of the specified metrics going up:

![alt text](images/progra/autoscale1.png)

And alert has been produced:

![alt text](images/progra/autoscale2.png)

Then we check the number of pod or MS again:
```
NAME                             READY   STATUS    RESTARTS   AGE
wls-k8s-domain-admin-server      1/1     Running   0          83m
wls-k8s-domain-managed-server1   1/1     Running   0          82m
wls-k8s-domain-managed-server2   1/1     Running   0          29m
wls-k8s-domain-managed-server3   1/1     Running   0          3m26s
```
We can see that the third node Age is just 3 minutes which is a sign that this is new pod or MS.
