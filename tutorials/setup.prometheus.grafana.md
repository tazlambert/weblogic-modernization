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

### Setup  ###

#### Setting Up Prometheus ####
