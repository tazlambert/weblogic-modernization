
# Oracle WebLogic Operator Tutorial #

### Ingress Controller and Load Balancer using Nginx  ###

The Oracle WebLogic Server Kubernetes Operator supports Oracle Cloud Infrastructure Load Balancer, the sample can be seen from the [documentation](https://docs.cloud.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupingresscontroller.htm). It is recommended for Production purpose to use this configuration. This tutorial demonstrates how to configure Kubernetes to provisions Ingress Controller and Load Balancer.

### Creating Ingress Controller  ###

Go to your bastion host and copy paste this command to create Ingress Controller:

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml

The above script will create several resources such as namespaces, configMap, etc.

    namespace/ingress-nginx created
    configmap/nginx-configuration created
    configmap/tcp-services created
    configmap/udp-services created
    serviceaccount/nginx-ingress-serviceaccount created
    clusterrole.rbac.authorization.k8s.io/nginx-ingress-clusterrole unchanged
    role.rbac.authorization.k8s.io/nginx-ingress-role created
    rolebinding.rbac.authorization.k8s.io/nginx-ingress-role-nisa-binding created
    clusterrolebinding.rbac.authorization.k8s.io/nginx-ingress-clusterrole-nisa-binding unchanged
    deployment.apps/nginx-ingress-controller created
    limitrange/ingress-nginx created

### Creating Load Balancer  ###

After that copy, paste, and execute this script below to create Ingress Controller service as Load Balancer, pay attention to namespace that need to be the same from the previous output and the port that want to open:

    cat << EOF | kubectl apply -f -
    kind: Service
    apiVersion: v1
    metadata:
      name: ingress-nginx
      namespace: ingress-nginx
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
    spec:
      type: LoadBalancer
      selector:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      ports:
        - name: http
          port: 80
          targetPort: http
        - name: https
          port: 443
          targetPort: https
    EOF

The result from the script is

    service/ingress-nginx created

To check the IP address of the Load Balancer execute this command:

    $ kubectl get svc -n ingress-nginx

    NAME            TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                       AGE
    ingress-nginx   LoadBalancer   10.96.229.38   129.146.214.219   80:30756/TCP,443:30118/TCP    1h

If the EXTERNAL-IP field is still <pending> please wait or check if you have hit 3 Public IP limit in the Tenancy.
    
There is also possibility to create Private Load Balancer that will not required IP Public then copy, paste, and execute this command, see the differents in the annotation part that said it is load balancer with shape 400Mbps, private and using which subnet to host the load balancer service.    

    cat << EOF | kubectl apply -f -
    kind: Service
    apiVersion: v1
    metadata:
      name: ingress-nginx
      namespace: ingress-nginx
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      annotations:
        service.beta.kubernetes.io/oci-load-balancer-shape: "400Mbps"
        service.beta.kubernetes.io/oci-load-balancer-internal: "true"
        service.beta.kubernetes.io/oci-load-balancer-subnet1: "ocid1.subnet.oc1.phx.aaaaaaaaqqc5ef3fiiv7vyrvyml3ozih6czxnqeus7zqhmdgtm6imxxe5lvq"
    spec:
      type: LoadBalancer
      selector:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      ports:
        - name: http
          port: 80
          targetPort: http
        - name: https
          port: 443
          targetPort: https
    EOF

The result from the script is

    service/ingress-nginx created
    
More options on oci-load-balancer for HTTP service can be found in the [documentation](https://docs.cloud.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengcreatingloadbalancer.htm). To check the IP address of the Load Balancer execute this command:

    $ kubectl get svc -n ingress-nginx

    NAME            TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                       AGE
    ingress-nginx   LoadBalancer   10.96.229.38   129.213.172.44    80:30756/TCP,443:30118/TCP    1h
    ingress-nginx-i LoadBalancer   10.96.229.58   10.1.14.29        80:30756/TCP,443:30118/TCP    1h

### Creating Ingress to Access Weblogic Domain  ###

To enable access from outside kubernetes cluster an Ingress need to be created as mapping from Load Balancer to Backend, please copy, paste, and execute this command, pay attention to the service name and service port of the weblogic cluster and admin server:

    cat << EOF | kubectl apply -f -
    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
      name: nginx-pathrouting
      namespace: wls-k8s-domain-ns
      annotations:
        kubernetes.io/ingress.class: "nginx"
    spec:
      rules:
      - host:
        http:
          paths:
          - path: /
            backend:
              serviceName: wls-k8s-domain-cluster-cluster-1
              servicePort: 8001
          - path: /console
            backend:
              serviceName: wls-k8s-domain-admin-server
              servicePort: 7001    
    EOF

This will enable access from outside using both Public and Private load balancer that just created. Testing can be done by trying accessing the deployed Weblogic admin server and application by constructing the URL of the admin console based on the following pattern:

`http://EXTERNAL-IP/console`

The EXTERNAL-IP was determined during Traefik install. If you forgot to note the execute the following command to get the public IP address:
```
    $ kubectl get svc -n ingress-nginx

    NAME            TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                       AGE
    ingress-nginx   LoadBalancer   10.96.229.38   129.213.172.44    80:30756/TCP,443:30118/TCP    1h
    ingress-nginx-i LoadBalancer   10.96.229.58   10.1.14.29        80:30756/TCP,443:30118/TCP    1h
```
Construct the Administration Console's url and open in a browser:

Enter admin user credentials (weblogic/welcome1) and click **Login**

![](images/deploy.domain/weblogic.console.login.png)

!Please note in this use case the use of Administration Console is just for demo/test purposes because domain configuration persisted in pod which means after the restart the original values (baked into the image) will be used again. To override certain configuration parameters - to ensure image portability - follow the override part of this tutorial.

#### Test the demo Web Application ####

The URL pattern of the sample application is the following:

`http://EXTERNAL-IP/opdemo/?dsname=testDatasource`

![](images/deploy.domain/webapp.png)

Refresh the page and notice the hostname changes. It reflects the managed server's name which responds to the request. You should see the load balancing between the two managed servers.

