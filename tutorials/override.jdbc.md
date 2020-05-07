# Override JDBC Datasource Parameters #

You can modify the WebLogic domain configuration for both the "domain in persistent volume" and the "domain in image" options before deploying a domain resource:

- When the domain is in a persistent volume, you can use WLST or WDT to change the configuration.
- For either case you can use configuration overrides.

Use configuration overrides (also called situational configuration) to customize a WebLogic domain home configuration without modifying the domain's actual `config.xml` or system resource files. For example, you may want to override a JDBC datasource XML module user name and URL so that it references a different database.

You can use overrides to customize domains as they are moved from QA to production, are deployed to different sites, or are even deployed multiple times at the same site.

Overrides leverage a built-in WebLogic feature called "Configuration Overriding" which is often informally called "Situational Configuration." Situational configuration consists of XML formatted files that closely resemble the structure of WebLogic config.xml and system resource module XML files. In addition, the attribute fields in these files can embed add, replace, and delete verbs to specify the desired override action for the field.

For more details see the [Configuration overrides documentation](https://github.com/oracle/weblogic-kubernetes-operator/blob/2.0/site/config-overrides.md)

#### Prepare JDBC override ####

The operator requires a different file name format for override templates. For JDBC it has to be `jdbc-MODULENAME.xml`. A MODULENAME must correspond to the MBean name of a system resource defined in your original `config.xml` file.

The custom WebLogic image - you created using Oracle Pipelines - has a JDBC Datasource called *testDatasource*. So you have to create a template which name is *jdbc-testDatasource.xml*.
Before create the necessary files first make a directory which will contain only the situational JDBC configuration template and a `version.txt` file.
```
mkdir -p /u01/override
```
Create the template file:
```
cat > /u01/override/jdbc-testDatasource.xml <<'EOF'
<?xml version='1.0' encoding='UTF-8'?>
<jdbc-data-source xmlns="http://xmlns.oracle.com/weblogic/jdbc-data-source"
                  xmlns:f="http://xmlns.oracle.com/weblogic/jdbc-data-source-fragment"
                  xmlns:s="http://xmlns.oracle.com/weblogic/situational-config">
  <name>testDatasource</name>
  <jdbc-driver-params>
    <url f:combine-mode="replace">${secret:dbsecret.url}</url>
    <properties>
       <property>
          <name>user</name>
          <value f:combine-mode="replace">${secret:dbsecret.username}</value>
       </property>
    </properties>
  </jdbc-driver-params>
</jdbc-data-source>
EOF
```
Note! This template contains macro to override the JDBC user name and URL parameters. The values referred from Kubernetes secret.

Now create the *version.txt* which reflects the version of the operator.
```
cat > /u01/override/version.txt <<EOF
2.0
EOF
```
Now create a Kubernetes configuration map (*jdbccm*) from the directory of template and version file.
```
kubectl -n wls-k8s-domain-ns create cm jdbccm --from-file /u01/override
kubectl -n wls-k8s-domain-ns label cm jdbccm weblogic.domainUID=wls-k8s-domain
```
Please note the name of the configuration map which is: *jdbccm*.

You can check the configuration map what you created:
```
$ kubectl describe cm jdbccm -n wls-k8s-domain-ns
Name:         jdbccm
Namespace:    wls-k8s-domain-ns
Labels:       weblogic.domainUID=wls-k8s-domain
Annotations:  <none>

Data
====
jdbc-testDatasource.xml:
----
<?xml version='1.0' encoding='UTF-8'?>
<jdbc-data-source xmlns="http://xmlns.oracle.com/weblogic/jdbc-data-source"
                  xmlns:f="http://xmlns.oracle.com/weblogic/jdbc-data-source-fragment"
                  xmlns:s="http://xmlns.oracle.com/weblogic/situational-config">
  <name>testDatasource</name>
  <jdbc-driver-params>
    <url f:combine-mode="replace">${secret:dbsecret.url}</url>
    <properties>
       <property>
          <name>user</name>
          <value f:combine-mode="replace">${secret:dbsecret.username}</value>
       </property>
    </properties>
  </jdbc-driver-params>
</jdbc-data-source>

version.txt:
----
2.0

Events:  <none>
```

The last thing what you need to create the secret which contains the values of the JDBC user name and URL parameters.
To create secret execute the following `kubectl` command:
```
kubectl -n wls-k8s-domain-ns create secret generic dbsecret --from-literal=username=scott2 --from-literal=url=jdbc:oracle:thin:@test.db.example.com:1521/ORCLCDB
kubectl -n wls-k8s-domain-ns label secret dbsecret weblogic.domainUID=wls-k8s-domain
```
Please note values (*username=scott2*, *url=jdbc:oracle:thin:@test.db.example.com:1521/ORCLCDB*) and the name of the secret which is: *dbsecret*.

Before applying changes check the current JDBC parameters using the demo Web Application. Open using the following URL pattern:

`http://EXTERNAL-IP/opdemo/?dsname=testDatasource`

![](images/override/original.jdbc.properties.png)

Note the value of the Database User and the Database URL.

The final step is to modify the domain resource definition (*domain.yaml*) to include override configuration map and secret.

Open the *domain.yaml* and in the `spec:` section add (or append) the following entries. Be careful to keep the indentation properly:
```
spec:
  [ ... ]
  configOverrides: jdbccm
  configOverrideSecrets: [dbsecret]
```
Save the changes of the domain resource definition file.

#### Restart the WebLogic domain ####

Any override changes require stopping all WebLogic pods, applying your domain resource (if it changed), and restarting the WebLogic pods before they can take effect.

To stop all running WebLogic Server pods in your domain, apply a changed resource, and then start the domain:

1. Open the *domainKube.yaml* again and set your domain resource `serverStartPolicy` to `NEVER`.

2. Apply changes:
```
kubectl apply -f /u01/domainKube.yaml
```
Check the pod's status:
```
$ kubectl get po -n wls-k8s-domain-ns
NAME                             READY     STATUS        RESTARTS   AGE
wls-k8s-domain-admin-server      1/1       Terminating   0          1h
wls-k8s-domain-managed-server1   1/1       Terminating   0          1h
$ kubectl get po -n wls-k8s-domain-ns
No resources found.
```
Wait till all pods are terminated and no resources found.

3. Open the *domainKube.yaml* again and set your domain resource `serverStartPolicy` back to `IF_NEEDED`.

4. Apply changes:
```
kubectl apply -f /u01/domainKube.yaml
```
Check the pod's status periodically and wait till all the pods are up and ready:
```
$ kubectl get po -n wls-k8s-domain-ns
NAME                             READY     STATUS    RESTARTS   AGE
wls-k8s-domain-admin-server      1/1       Running   0          2m
wls-k8s-domain-managed-server1   1/1       Running   0          1m
```

Now check the expected values of the JDBC datasource using the demo Web Application again:

`http://EXTERNAL-IP/opdemo/?dsname=testDatasource`

![](images/override/updated.jdbc.properties.png)

You have to see the following changes:
- **Database User**: scott2
- **Database URL**: jdbc:oracle:thin:@test.db.example.com:1521/ORCLCDB
