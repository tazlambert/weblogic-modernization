# Assigning WebLogic Pods to Nodes #

When you create a Managed server (Pod), the Kubernetes scheduler selects a node for the Pod to run on. The scheduler ensures that, for each resource type, the sum of the resource requests of the scheduled Containers is less than the capacity of the node. Note that although actual memory or CPU resource usage on nodes is very low, the scheduler still refuses to place a Pod on a node if the capacity check fails.

However you can create affinity with a `nodeSelector` to constrain a pod to only be able to run on particular nodes. Generally such constraints are unnecessary, as the scheduler will automatically do a reasonable placement but there are some circumstances where you may want more control on a node where a pod lands, e.g.:

- to ensure that a pod ends up on a machine with an SSD attached to it
- to co-locate pods from two different services that communicate a lot into the same availability zone
- to ensure pods end up in different availability zone for better high availability
- to move away (*draining*) all pods from given node because of maintenance reason
- to ensure that pod's runs certain software ends up on licensed environment.

In this lab you will learn how to assign pods individual Managed Server and or the whole Domain to particular node(s).

#### Create affinity  ####

##### Assign particular servers to specific nodes #####

To assign pod(s) to node(s) you need to label the desired node with custom tag. Then define the `nodeSelector` property in the domain resource definition and set the value of the label you applied on the node. Finally apply the domain configuration changes.

First get the node names using `kubectl get node`:
```
$ kubectl get node
NAME             STATUS    ROLES     AGE       VERSION
130.61.110.174   Ready     node      11d       v1.15.7
130.61.52.240    Ready     node      11d       v1.15.7
130.61.84.41     Ready     node      11d       v1.15.7
```

In case of OKE the node name can be the Public IP address of the node or the subnet's CIDR Block's first IP address. But obviously a unique string which identifies the node.

Now check the current pod allocation using the detailed pod information `kubectl get pod -n wls-k8s-domain-ns -o wide`:
```
$ kubectl get pod -n wls-k8s-domain-ns -o wide
NAME                             READY     STATUS    RESTARTS   AGE       IP            NODE             NOMINATED NODE
wls-k8s-domain-admin-server      1/1       Running   0          2m        10.244.2.33   130.61.84.41     <none>
wls-k8s-domain-managed-server1   1/1       Running   0          1m        10.244.1.8    130.61.52.240    <none>
wls-k8s-domain-managed-server2   1/1       Running   0          1m        10.244.0.10   130.61.110.174   <none>
wls-k8s-domain-managed-server3   1/1       Running   0          1m        10.244.2.34   130.61.84.41     <none>
```

As you can see from the result Kubernetes evenly deployed the 3 managed servers to the 3 worker nodes. In this case we can e.g. evacuate one of the node. If you have an empty node scenario then you can assign 1 managed server/pod to 1 node. Just adopt the labelling and domain resource definition modification accordingly.

###### Labelling ######

Knowing the node names select one which you want to make empty. In this example this node will be: `130.61.110.174`

Label the other nodes. The label can be any string, but let's use `wlservers1` and `wlservers2`. Execute `kubectl label nodes <nodename> <labelname>=true` command but replace your node name and label properly:
```
$ kubectl label nodes 130.61.52.240 wlservers1=true
node/130.61.52.240 labeled
$ kubectl label nodes 130.61.84.41 wlservers2=true
node/130.61.84.41 labeled
```
###### Modify domain resource definition ######

Open your `domainKube.yaml` in text editor and find the `adminServer:` entry and insert a new property where you can define the placement of the admin server:
```
adminServer:
  [...]
  serverPod:
    nodeSelector:
      wlservers2: true
```
Assign 2-2 servers (including admin) to 1-1 labelled node.
You can double check the syntax in the sample [domain.yaml](https://github.com/tazlambert/weblogic-operator-tutorial/blob/master/domainKube.yaml) where this part turned into comment.

For the managed servers you have to insert `managedServers:` which has to be at the same level (indentation) with `adminServer:`. In this property you need to use WebLogic server name to identify the pod. The server name is defined during WebLogic image creation and if you followed this tutorial it is `managed-serverX`.
```
spec:
  [...]
  managedServers:
  - serverName: managed-server1
    serverPod:
      nodeSelector:
        wlservers1: true
  - serverName: managed-server2
    serverPod:
      nodeSelector:
        wlservers1: true
  - serverName: managed-server3
    serverPod:
      nodeSelector:
        wlservers2: true
  [...]
```
Save the changes and apply the new domain resource definition.
```
$ kubectl apply -f /u01/domainKube.yaml
domain.weblogic.oracle/wls-k8s-domain configured
```
The operator according to the changes will start to relocate servers. Poll the pod information and wait until the expected result:
```
$ kubectl get po -n wls-k8s-domain-ns -o wide
NAME                             READY     STATUS        RESTARTS   AGE       IP            NODE            NOMINATED NODE
sample-domain1-admin-server      1/1       Running       0          3m        10.244.2.36   130.61.84.41    <none>
sample-domain1-managed-server1   1/1       Running       0          55m       10.244.1.8    130.61.52.240   <none>
sample-domain1-managed-server2   1/1       Running       0          56s       10.244.1.9    130.61.52.240   <none>
sample-domain1-managed-server3   1/1       Running       0          2m        10.244.2.37   130.61.84.41    <none>
```

##### Delete label and `nodeSelector` entries in `domainKube.yaml` #####

To delete the node assignment delete the node's label using `kubectl label node <nodename> <labelname>-` command but replace the node name properly:
```
$ kubectl label nodes 130.61.52.240 wlservers1-
node/130.61.52.240 labeled
$ kubectl label nodes 130.61.84.41 wlservers2-
node/130.61.84.41 labeled
```
Delete or turn into comment the entries you added for node assignment in your `domain.yaml` and apply:
```
$ kubectl apply -f /u01/domainKube.yaml
domain.weblogic.oracle/wls-k8s-domain configured
```
The pod reallocation/restart can happen based on the scheduler decision.

## Assigning WebLogic Pods to Licensed Node ##

This use case similar to described in [Assigning WebLogic Pods to Nodes lab](node.selector.md) where individual servers/pods were asssigned to specific node(s). However the focus in this use case on the license coverage.

At v1.13, Kubernetes supports clusters with up to 5000(!) nodes. However certain software like WebLogic requires license. Using `nodeSelector` feature Kubernetes ensure that WebLogic pods end up on licenced worker node(s).

In this lab you will learn how to assign all WebLogic pods (WebLogic domain) to particular node(s).

#### Assign WebLogic servers/pods to licensed nodes #####

To assign pod(s) to node(s) you need to label the desired node with custom tag. Then define the `nodeSelector` property in the domain resource definition and set the value of the label you applied on the node. Finally apply the domain configuration changes.

First get the node names using `kubectl get node`:
```
$ kubectl get node
NAME             STATUS    ROLES     AGE       VERSION
130.61.110.174   Ready     node      11d       v1.15.7
130.61.52.240    Ready     node      11d       v1.15.7
130.61.84.41     Ready     node      11d       v1.15.7
```

In case of OKE the node name can be the Public IP address of the node or the subnet's CIDR Block's first IP address. But obviously a unique string which identifies the node.

Now check the current pod allocation using the detailed pod information `kubectl get pod -n wls-k8s-domain-ns -o wide`:
```
$ kubectl get pod -n wls-k8s-domain-ns -o wide
NAME                             READY     STATUS    RESTARTS   AGE       IP            NODE             NOMINATED NODE
wls-k8s-domain-admin-server      1/1       Running   0          2m        10.244.2.33   130.61.84.41     <none>
wls-k8s-domain-managed-server1   1/1       Running   0          1m        10.244.1.8    130.61.52.240    <none>
wls-k8s-domain-managed-server2   1/1       Running   0          1m        10.244.0.10   130.61.110.174   <none>
wls-k8s-domain-managed-server3   1/1       Running   0          1m        10.244.2.34   130.61.84.41     <none>
```

As you can see from the result Kubernetes evenly deployed the 3 managed servers to the 3 worker nodes. In this scenario choose one of the node where you want to move all pods.

###### Labelling ######

In this example the licensed node will be: `130.61.84.41`

Label this node. The label can be any string, but now use `licensed-for-weblogic`. Execute `kubectl label nodes <nodename> <labelname>=true` command but replace your node name and label properly:
```
$ kubectl label nodes 130.61.84.41 licensed-for-weblogic=true
node/130.61.84.41 labeled
```
###### Modify domain resource definition ######

Open your `domainKube.yaml` in text editor and find the `serverPod:` entry and insert a new property inside:
```
serverPod:
  env:
  [...]
  nodeSelector:
    licensed-for-weblogic: true
```
Be careful with the indentation. You can double check the syntax in the sample [domainKube.yaml](https://github.com/tazlambert/weblogic-operator-tutorial/blob/master/domainKube.yaml) where this part turned into comment.

Save the changes and apply the new domain resource definition.
```
$ kubectl apply -f /u01/domainKube.yaml
domain.weblogic.oracle/wls-k8s-domain configured
```
The operator according to the changes will start to relocate servers. Poll the pod information and wait until the expected result:
```
$ kubectl get po -n wls-k8s-domain-ns -o wide
NAME                             READY     STATUS    RESTARTS   AGE       IP            NODE           NOMINATED NODE
wls-k8s-domain-admin-server      1/1       Running   0          4h        10.244.2.40   130.61.84.41   <none>
wls-k8s-domain-managed-server1   1/1       Running   0          4h        10.244.2.43   130.61.84.41   <none>
wls-k8s-domain-managed-server2   1/1       Running   0          4h        10.244.2.42   130.61.84.41   <none>
wls-k8s-domain-managed-server3   1/1       Running   0          4h        10.244.2.41   130.61.84.41   <none>
```

##### Delete label and `nodeSelector` entries in `domainKube.yaml` #####

To delete the node assignment delete the node's label using `kubectl label node <nodename> <labelname>-` command but replace the node name properly:
```
$ kubectl label nodes 130.61.84.41 licensed-for-weblogic-
node/130.61.84.41 labeled
```
Delete or turn into comment the entries you added for node assignment in your `domain.yaml` and apply:
```
$ kubectl apply -f /u01/domainKube.yaml
domain.weblogic.oracle/wls-k8s-domain configured
```
The pod reallocation/restart can happen based on the scheduler decision.
