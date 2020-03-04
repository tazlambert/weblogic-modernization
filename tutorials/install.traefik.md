# Oracle WebLogic Operator Tutorial #

### Install and configure Traefik  ###

The Oracle WebLogic Server Kubernetes Operator supports three load balancers: Traefik, Voyager, and Apache. Samples are provided in the [documentation](https://github.com/oracle/weblogic-kubernetes-operator/blob/2.0/kubernetes/samples/charts/README.md).

This tutorial demonstrates how to install the [Traefik](https://traefik.io/) ingress controller to provide load balancing for WebLogic clusters.

#### Install the Traefik operator with a Helm chart ####

Change to your WebLogic Operator local Git repository folder.

    cd /u01/content/weblogic-kubernetes-operator/

To install the Traefik operator in the traefik namespace with the provided sample values:

    helm install stable/traefik \
    --name traefik-operator \
    --namespace traefik \
    --values kubernetes/samples/charts/traefik/values.yaml  \
    --set "kubernetes.namespaces={traefik}" \
    --set "serviceType=LoadBalancer" 

The output should be similar:

    NAME:   traefik-operator
    LAST DEPLOYED: Tue Mar  3 07:40:36 2020
    NAMESPACE: traefik
    STATUS: DEPLOYED

    RESOURCES:
    ==> v1/ConfigMap
    NAME              DATA  AGE
    traefik-operator  1     0s

    ==> v1/Deployment
    NAME              READY  UP-TO-DATE  AVAILABLE  AGE
    traefik-operator  0/1    1           0          0s

    ==> v1/Pod(related)
    NAME                               READY  STATUS             RESTARTS  AGE
    traefik-operator-54d45cf7b8-pbn8r  0/1    ContainerCreating  0         0s

    ==> v1/Role
    NAME              AGE
    traefik-operator  0s

    ==> v1/RoleBinding
    NAME              AGE
    traefik-operator  0s

    ==> v1/Secret
    NAME                           TYPE    DATA  AGE
    traefik-operator-default-cert  Opaque  2     0s

    ==> v1/Service
    NAME                        TYPE          CLUSTER-IP    EXTERNAL-IP  PORT(S)                     AGE
    traefik-operator            LoadBalancer  10.96.94.216  <pending>    443:32265/TCP,80:31959/TCP  0s
    traefik-operator-dashboard  ClusterIP     10.96.54.225  <none>       80/TCP                      0s

    ==> v1/ServiceAccount
    NAME              SECRETS  AGE
    traefik-operator  1        0s

    ==> v1beta1/Ingress
    NAME                        HOSTS                ADDRESS  PORTS  AGE
    traefik-operator-dashboard  traefik.example.com  80       0s


    NOTES:

    1. Get Traefik's load balancer IP/hostname:

         NOTE: It may take a few minutes for this to become available.

         You can watch the status by running:

             $ kubectl get svc traefik-operator --namespace traefik -w

         Once 'EXTERNAL-IP' is no longer '<pending>':

             $ kubectl describe svc traefik-operator --namespace traefik | grep Ingress | awk '{print $3}'

    2. Configure DNS records corresponding to Kubernetes ingress resources to point to the load balancer IP/hostname found in step 1

The Traefik installation is basically done. Verify the Traefik (Loadbalancer) services:
```
kubectl get service -n traefik
NAME                         TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                      AGE
traefik-operator             LoadBalancer   10.96.94.216   129.146.154.105   443:32265/TCP,80:31959/TCP   58s
traefik-operator-dashboard   ClusterIP      10.96.54.225   <none>            80/TCP                       58s
```
Please note the EXTERNAL-IP of the *traefik-operator* service. This is the Public IP address of the Loadbalancer what you will use to open the WebLogic admin console and the sample application.

To print only the Public IP address you can execute this command:
```
$ kubectl describe svc traefik-operator --namespace traefik | grep Ingress | awk '{print $3}'
129.146.154.105
```

Verify the `helm` charts:

    $ helm list
    NAME                            REVISION        UPDATED                         STATUS          CHART                   APP VERSION     NAMESPACE
    sample-weblogic-operator        1               Tue Mar  3 07:37:47 2020        DEPLOYED        weblogic-operator-2.5.0                 sample-weblogic-operator-ns
    traefik-operator                1               Tue Mar  3 07:40:36 2020        DEPLOYED        traefik-1.86.1          1.7.20          traefik

You can also hit the Traefik's dashboard using `curl`. Use the EXTERNAL-IP address from the result above:

    curl -H 'host: traefik.example.com' http://EXTERNAL_IP_ADDRESS

For example:

    $ curl -H 'host: traefik.example.com' http://129.146.154.105
    <a href="/dashboard/">Found</a>.
