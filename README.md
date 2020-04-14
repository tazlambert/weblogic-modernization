# Welcome to Oracle WebLogic Move and Improve Hands On Lab #

### About this hands-on Hands On Lab ###

This Hands On Lab is made based on the [WebLogic Kubernetes Operator Documentation](https://oracle.github.io/weblogic-kubernetes-operator/) also various references and has been tested by April 2020.

The Hands On Lab will demonstrates:
+ **Convert existing WebLogic Domain to docker image** using [Weblogic Deploy Tooling](https://github.com/oracle/weblogic-deploy-tooling) and [WebLogic Image Tool](https://github.com/oracle/weblogic-image-tool)
+ **Improve existing WebLogic Domain** by REST enabling Weblogic metrics for monitoring using [WebLogic Monitoring Exporter](https://github.com/oracle/weblogic-monitoring-exporter) and making WebLogic Log into JSON to be consumed by Elasticsearch using [WebLogic Logging Exporter](https://github.com/oracle/weblogic-logging-exporter) 
+ **Automating WebLogic Domain Lifecycle in CI/CD process**, which will include working with [Oracle Cloud Infrastructure](https://docs.cloud.oracle.com/en-us/iaas/Content/GSG/Concepts/baremetalintro.htm), [Oracle Container Pipelines/Wercker](https://docs.oracle.com/en/cloud/iaas/wercker-cloud/wercm/), [Oracle Container Engine for Kubernetes](https://docs.cloud.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengoverview.htm), [Github](https://github.com/), [Oracle Registry](https://docs.cloud.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm), and lastly [WebLogic Kubernetes Operator](https://github.com/oracle/weblogic-kubernetes-operator).

This lab is designed for people with no prior experience with OCI, Kubernetes, WebLogic, WebLogic Tooling, Container Registry, Docker and want to learn the core concepts and basics of how to run WebLogic JEE application on Kubernetes environment.

Oracle services being used during the hands-on are the following:

+ **Oracle Cloud Infrastructure (OCI)** which combines the elasticity and utility of public cloud with the granular control, security, and predictability of on-premises infrastructure to deliver high-performance, high availability and cost-effective infrastructure services.
+ **Oracle Container Pipelines (OCP - former Wercker)** is a Docker-Native CI/CD  Automation platform for Kubernetes & Microservice Deployments. OCP is integrated with Docker containers, which package up application code and can be easily moved from server to server. Each build artifact can be a Docker container. The user can take the container from the Docker Hub or his private registry and build the code before shipping it. Its SaaS platform enables developers to test and deploy code often. They can push software updates incrementally as they are ready, rather than in bundled dumps. It makes it easier for coders to practice continuous integration, a software engineering practice in which each change a developer makes to the codebase is constantly tested in the process so that software doesn’t break when it goes live.
+ **Oracle Cloud Infrastructure Registry (OCIR)** is a v2 container registry hosted on OCI to store and retrieve containers.
+ **Oracle Container Engine for Kubernetes (OKE)** is an Oracle managed Kubernetes Cluster enviroment to deploy and run container packaged applications.
+ **Oracle Weblogic Kubernetes Operator** open source component to run WebLogic on Kubernetes.

### The topics to be covered in this tutorial: ###

### Deploy Oracle WebLogic Domain (*Domain-home-in-image*) on Kubernetes using Oracle WebLogic Operator  ###

This lab demonstrates how to deploy and run Weblogic Domain container packaged Web Application on Kubernetes Cluster using [Oracle WebLogic Server Kubernetes Operator 2.4.0](https://github.com/oracle/weblogic-kubernetes-operator).

The demo Web Application is a simple JSP page which shows WebLogic Domain's MBean attributes to demonstrate WebLogic Operator features.

**Architecture**

WebLogic domain can be located either in a persistent volume (PV) or in a Docker image. [There are advantages to both approaches, and there are sometimes technical limitations](https://github.com/oracle/weblogic-kubernetes-operator/blob/2.0/site/domains.md#create-and-manage-weblogic-domains) of various cloud providers that may make one approach better suited to your needs.

This tutorial implements the Docker image with the WebLogic domain inside the image deployment. This means all the artefacts, domain related files are stored within the image. There is no central, shared domain folder from the pods. This is similar to the standard installation topology where you distribute your domain to different host to scale out Managed servers. The main difference is that using container packaged WebLogic Domain you don't need to use pack/unpack mechanism to distribute domain binaries and configuration files between multiple host.

![](tutorials/images/wlsonk8s.domain-home-in-image.png)

In Kubernetes environment WebLogic Operator ensures that only one Admin and multiple Managed servers will run in the domain. An operator is an application-specific controller that extends Kubernetes to create, configure, and manage instances of complex applications. The Oracle WebLogic Server Kubernetes Operator (the "operator") simplifies the management and operation of WebLogic domains and deployments.

Helm is a framework that helps you manage Kubernetes applications, and helm charts help you define and install Helm applications into a Kubernetes cluster. Helm has two parts: a client (Helm) and a server (Tiller). However, in [Helm 3](https://helm.sh/blog/helm-3-released/) Tiller has been removed, latest version still using Tiller is Helm v2.16.2 . Tiller runs inside of your Kubernetes cluster, and manages releases (installations) of your charts.

This tutorial has been tested on Oracle Cloud Infrastructure Container Engine for Kubernetes (OKE).

### Prerequisites ###

- [Oracle Cloud Infrastructure](https://cloud.oracle.com/en_US/cloud-infrastructure) enabled account. The tutorial has been tested using [Trial account](https://myservices.us.oraclecloud.com/mycloud/signup) (as of January, 2019).
- Desktop with Oracle Cloud Infrastructure CLI, `kubectl`, `helm`. [Download](https://drive.google.com/open?id=11CvOZ-j50-2q9-rrQmxpEwmQZbPMkw2a) and import the preconfigured VirtualBox image (total required space > 12 GB)
  - [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads) if necessary.
- [Docker](https://hub.docker.com/) account.
- [Github ](sign.up.github.md) account.
- [Oracle Container Pipeline](sign.up.wercker.md)

#### Before you start update HOL desktop environment (VirtualBox image) ####

Depending on your network connection make sure you switched ON or OFF the proxy configuration by clicking the corresponding shortcut on the desktop.

After the proxy configuration double click the **Update** icon and wait until the update process complete. Hit enter when you see the *Press [Enter] to close the window* message to close the update terminal.

![](tutorials/images/update.HOL.png)

### The topics to be covered in this hands-on session are: ###

0. [Setup Oracle Kubernetes Engine instance on Oracle Cloud Infrastructure.](tutorials/setup.oke.md)
1. [Create Oracle Container Pipelines Application to Build Custom WebLogic Domain Image](tutorials/build.weblogic.image.pipeline.md)
2. [Install WebLogic Operator](tutorials/install.operator.md)
3. [Deploy WebLogic Domain](tutorials/deploy.weblogic.md)
4. [Deploy Ingress Load Balancer](tutorials/deploy.load.balancer.md)
5. [Scaling WebLogic Cluster](tutorials/scale.weblogic.md)
6. [Override JDBC Datasource parameters](tutorials/override.jdbc.md)
7. [Update Web Application](tutorials/update.application.md)
8. [Assigning WebLogic Pods to Nodes](tutorials/node.selector.md)
9. [Assigning WebLogic Pods to Licensed Nodes](tutorials/node.selector.license.md)

### License ###
Copyright (c) 2020 Oracle and/or its affiliates
The Universal Permissive License (UPL), Version 1.0
