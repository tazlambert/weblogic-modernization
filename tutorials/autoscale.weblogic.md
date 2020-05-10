# Auto Scaling WebLogic Cluster #

The idea of autosacling is adding managed server automatically based on rules that is created and the rules will be measured based on the metrics that come from WebLogic Cluster;

- Using a WLDF policy rule and script action to call the operator's REST scale API.
- Using a Prometheus alert action to call the operator's REST scale API.

#### Scaling WebLogic cluster using WLDF  ####

The WebLogic Diagnostics Framework (WLDF) is a suite of services and APIs that collect and surface metrics that provide visibility into server and application performance. To support automatic scaling of WebLogic clusters in Kubernetes, WLDF provides the Policies and Actions component, which lets you write policy expressions for automatically executing scaling operations on a cluster. These policies monitor one or more types of WebLogic Server metrics, such as memory, idle threads, and CPU load. When the configured threshold in a policy is met, the policy is triggered, and the corresponding scaling action is executed. The WebLogic Server Kubernetes Operator project provides a shell script, scalingAction.sh, for use as a Script Action, which illustrates how to issue a request to the operator’s REST endpoint.

For this labs we are going to copy the original scalingAction.sh into 2 shell script; one is to scale up, scalingActionUp.sh, and one to scale down, scalingActionDown.sh. Here is the original parameter (line 7-17) that is needed to be change:
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
For scalingActionUp.sh it will be:
```
echo "called scalingActionUp.sh" >> scalingActionUp.log

# environment variable from admin-server pod ENV

KUBERNETES_SERVICE_HOST=10.96.0.1
KUBERNETES_SERVICE_PORT=443
INTERNAL_OPERATOR_CERT=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR5ekNDQXJPZ0F3SUJBZ0lFYkdpTVREQU5CZ2txaGtpRzl3MEJBUXNGQURBY01Sb3dHQVlEVlFRREV4RjMNClpXSnNiMmRwWXkxdmNHVnlZWFJ2Y2pBZUZ3MHlNREExTVRBd05qRTFOVE5hRncwek1EQTFNRGd3TmpFMU5UTmENCk1Cd3hHakFZQmdOVkJBTVRFWGRsWW14dloybGpMVzl3WlhKaGRHOXlNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUYNCkFBT0NBUThBTUlJQkNnS0NBUUVBcjhkei9ybFMrb2xyTEdacWdSWW1OL3crY0JaRXg4WU0wY2Z2RTY2dlcwa00NCjVja1c3LzFaS0g1SmlzTmlXWHQ4dkpWVTZhbnlBSE51WnpzMnBGT2NydVJMcld0djljK0oyTFg5WkR4N2s0WFcNCjZyR09ObkRoem40c1BCZ0crRCs3M0VMUW4zVkhoR3NwbWZua3JqdEFOSzRGczJqT0Jib0hNa0hLYWIrUTZSb0ENCmhVL2VFT21NczJEcDg1TmlTdXFlTDNVeFFURFZ2ZTJRRlhlWWdyQkl6ODJ4OWZkcXJOem5pN0toU09BbXpxOCsNCmtlL3hlYlU3OFVDMzR3MjZYWGNnVHI0RmdPTkpCaGdpZDZqUVl5V2RoTDRoZWRiUUM4dWtkaUJvak1PdFl1bE8NCmoxdUs3S2c1Z3lEcjF4cktBMlpUY01OM2NkTzFZUHVqL3BRcnNjQU45UUlEQVFBQm80SUJFekNDQVE4d0hRWUQNClZSME9CQllFRlBoaUY2ejYxaHIrYUtpN3NlSUdobGhDR0hLaU1Bc0dBMVVkRHdRRUF3SUQrRENCNEFZRFZSMFINCkJJSFlNSUhWZ2g1cGJuUmxjbTVoYkMxM1pXSnNiMmRwWXkxdmNHVnlZWFJ2Y2kxemRtT0NNMmx1ZEdWeWJtRnMNCkxYZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxYTjJZeTUzWldKc2IyZHBZeTF2Y0dWeVlYUnZjaTF1YzRJM2FXNTANClpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxXNXoNCkxuTjJZNEpGYVc1MFpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXcNClpYSmhkRzl5TFc1ekxuTjJZeTVqYkhWemRHVnlMbXh2WTJGc01BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQUENCjdzMnB5dk1FSG9lTGR6ZGN1NHk1VmtBZWdiVHlTR2MwTWUwUkR0elNBUVB6N0lCQllNLzg0R2ZkZGlmVWxwSkUNCnM1RGdmOWcxb2hzN0JBWDNZNlFOTVI3c2tDQ2o2OEUzK0RRSkpBUUUvbXhEak9mTnBvUGl3Z1QzMUcxSzdmelANCk40OUQ4Y09VZjNyTmVDaWhvREV6dDRROFlNb0RybHd6WTNzVnRDZXRLdzV3d1h1Ry9FakI2dEhwL2FXeGFSTE8NCndmMVN6RmVBTllmMDdrVkl4ZE5wbFV5RFdLYVN4VUhEYnhvM3d0YzBaQm1sU1VYNEFCZlRtOU1HZzZOcGp1ZlkNClpEOUVDNE40T2xGU0REYmpLSXBHL0Z0RTJXdHR4cHBrbGZLSDdzS3I0V1JlY2hCclBsNk9MNDVJUlFCdkVSZDkNCnhSZlNVWEJ2bFQ5Q3BHcG1ZZmN4Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K

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

# environment variable from admin-server pod ENV

KUBERNETES_SERVICE_HOST=10.96.0.1
KUBERNETES_SERVICE_PORT=443
INTERNAL_OPERATOR_CERT=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR5ekNDQXJPZ0F3SUJBZ0lFYkdpTVREQU5CZ2txaGtpRzl3MEJBUXNGQURBY01Sb3dHQVlEVlFRREV4RjMNClpXSnNiMmRwWXkxdmNHVnlZWFJ2Y2pBZUZ3MHlNREExTVRBd05qRTFOVE5hRncwek1EQTFNRGd3TmpFMU5UTmENCk1Cd3hHakFZQmdOVkJBTVRFWGRsWW14dloybGpMVzl3WlhKaGRHOXlNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUYNCkFBT0NBUThBTUlJQkNnS0NBUUVBcjhkei9ybFMrb2xyTEdacWdSWW1OL3crY0JaRXg4WU0wY2Z2RTY2dlcwa00NCjVja1c3LzFaS0g1SmlzTmlXWHQ4dkpWVTZhbnlBSE51WnpzMnBGT2NydVJMcld0djljK0oyTFg5WkR4N2s0WFcNCjZyR09ObkRoem40c1BCZ0crRCs3M0VMUW4zVkhoR3NwbWZua3JqdEFOSzRGczJqT0Jib0hNa0hLYWIrUTZSb0ENCmhVL2VFT21NczJEcDg1TmlTdXFlTDNVeFFURFZ2ZTJRRlhlWWdyQkl6ODJ4OWZkcXJOem5pN0toU09BbXpxOCsNCmtlL3hlYlU3OFVDMzR3MjZYWGNnVHI0RmdPTkpCaGdpZDZqUVl5V2RoTDRoZWRiUUM4dWtkaUJvak1PdFl1bE8NCmoxdUs3S2c1Z3lEcjF4cktBMlpUY01OM2NkTzFZUHVqL3BRcnNjQU45UUlEQVFBQm80SUJFekNDQVE4d0hRWUQNClZSME9CQllFRlBoaUY2ejYxaHIrYUtpN3NlSUdobGhDR0hLaU1Bc0dBMVVkRHdRRUF3SUQrRENCNEFZRFZSMFINCkJJSFlNSUhWZ2g1cGJuUmxjbTVoYkMxM1pXSnNiMmRwWXkxdmNHVnlZWFJ2Y2kxemRtT0NNMmx1ZEdWeWJtRnMNCkxYZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxYTjJZeTUzWldKc2IyZHBZeTF2Y0dWeVlYUnZjaTF1YzRJM2FXNTANClpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxXNXoNCkxuTjJZNEpGYVc1MFpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXcNClpYSmhkRzl5TFc1ekxuTjJZeTVqYkhWemRHVnlMbXh2WTJGc01BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQUENCjdzMnB5dk1FSG9lTGR6ZGN1NHk1VmtBZWdiVHlTR2MwTWUwUkR0elNBUVB6N0lCQllNLzg0R2ZkZGlmVWxwSkUNCnM1RGdmOWcxb2hzN0JBWDNZNlFOTVI3c2tDQ2o2OEUzK0RRSkpBUUUvbXhEak9mTnBvUGl3Z1QzMUcxSzdmelANCk40OUQ4Y09VZjNyTmVDaWhvREV6dDRROFlNb0RybHd6WTNzVnRDZXRLdzV3d1h1Ry9FakI2dEhwL2FXeGFSTE8NCndmMVN6RmVBTllmMDdrVkl4ZE5wbFV5RFdLYVN4VUhEYnhvM3d0YzBaQm1sU1VYNEFCZlRtOU1HZzZOcGp1ZlkNClpEOUVDNE40T2xGU0REYmpLSXBHL0Z0RTJXdHR4cHBrbGZLSDdzS3I0V1JlY2hCclBsNk9MNDVJUlFCdkVSZDkNCnhSZlNVWEJ2bFQ5Q3BHcG1ZZmN4Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K

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
For those two shell script we need to get the value of KUBERNETES_SERVICE_HOST, KUBERNETES_SERVICE_PORT, and INTERNAL_OPERATOR_CERT from the admin-server pod, which can be done by logging into the pod and use ENV command to show them.
```
kubectl exec -it wls-k8s-domain-admin-server -n wls-k8s-domain-ns -- /bin/bash
env
```
Expected result will be:
```
[oracle@wls-k8s-domain-admin-server wls-k8s-domain]$ env
LOCAL_ADMIN_PROTOCOL=t3
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_7001_TCP=tcp://10.96.213.13:7001
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_30012_TCP_ADDR=10.96.213.13
HOSTNAME=wls-k8s-domain-admin-server
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_SERVICE_HOST=10.96.213.13
KUBERNETES_PORT=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP_PORT=443
TERM=xterm
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_30012_TCP_PORT=30012
ADMIN_NAME=admin-server
KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_HOST=10.96.0.1
USER_MEM_ARGS=-Xms64m -Xmx256m
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT=tcp://10.96.213.13:30012
LC_ALL=en_US.UTF-8
JAVA_OPTIONS=-Dweblogic.StdoutDebugEnabled=false
LS_COLORS=rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;05;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.axa=01;36:*.oga=01;36:*.spx=01;36:*.xspf=01;36:
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_30012_TCP_PROTO=tcp
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_SERVICE_PORT_DEFAULT=7001
OPATCH_NO_FUSER=true
SERVER_OUT_IN_POD_LOG=true
AS_SERVICE_NAME=wls-k8s-domain-admin-server
DOMAIN_NAME=wls-k8s-domain
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/u01/jdk/bin:/u01/oracle/oracle_common/common/bin:/u01/oracle/wlserver/common/bin:/u01/oracle:$/u01/oracle/user_projects/domains/wls-k8s-domain/bin:/u01/oracle/user_projects/domains/wls-k8s-domain/bin
ADMIN_HOST=wlsadmin
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_7001_TCP_PROTO=tcp
DOMAIN_HOME=/u01/oracle/user_projects/domains/wls-k8s-domain
PWD=/u01/oracle/user_projects/domains/wls-k8s-domain
ADMIN_PORT=7001
SHUTDOWN_IGNORE_SESSIONS=false
JAVA_HOME=/u01/jdk
MANAGED_SERVER_PORT=8001
DOMAIN_UID=wls-k8s-domain
LOG_HOME=/shared/logs/wls-k8s-domain
LOCAL_ADMIN_PORT=7001
SERVICE_NAME=wls-k8s-domain-admin-server
INTERNAL_OPERATOR_CERT=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR5ekNDQXJPZ0F3SUJBZ0lFYkdpTVREQU5CZ2txaGtpRzl3MEJBUXNGQURBY01Sb3dHQVlEVlFRREV4RjMNClpXSnNiMmRwWXkxdmNHVnlZWFJ2Y2pBZUZ3MHlNREExTVRBd05qRTFOVE5hRncwek1EQTFNRGd3TmpFMU5UTmENCk1Cd3hHakFZQmdOVkJBTVRFWGRsWW14dloybGpMVzl3WlhKaGRHOXlNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUYNCkFBT0NBUThBTUlJQkNnS0NBUUVBcjhkei9ybFMrb2xyTEdacWdSWW1OL3crY0JaRXg4WU0wY2Z2RTY2dlcwa00NCjVja1c3LzFaS0g1SmlzTmlXWHQ4dkpWVTZhbnlBSE51WnpzMnBGT2NydVJMcld0djljK0oyTFg5WkR4N2s0WFcNCjZyR09ObkRoem40c1BCZ0crRCs3M0VMUW4zVkhoR3NwbWZua3JqdEFOSzRGczJqT0Jib0hNa0hLYWIrUTZSb0ENCmhVL2VFT21NczJEcDg1TmlTdXFlTDNVeFFURFZ2ZTJRRlhlWWdyQkl6ODJ4OWZkcXJOem5pN0toU09BbXpxOCsNCmtlL3hlYlU3OFVDMzR3MjZYWGNnVHI0RmdPTkpCaGdpZDZqUVl5V2RoTDRoZWRiUUM4dWtkaUJvak1PdFl1bE8NCmoxdUs3S2c1Z3lEcjF4cktBMlpUY01OM2NkTzFZUHVqL3BRcnNjQU45UUlEQVFBQm80SUJFekNDQVE4d0hRWUQNClZSME9CQllFRlBoaUY2ejYxaHIrYUtpN3NlSUdobGhDR0hLaU1Bc0dBMVVkRHdRRUF3SUQrRENCNEFZRFZSMFINCkJJSFlNSUhWZ2g1cGJuUmxjbTVoYkMxM1pXSnNiMmRwWXkxdmNHVnlZWFJ2Y2kxemRtT0NNMmx1ZEdWeWJtRnMNCkxYZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxYTjJZeTUzWldKc2IyZHBZeTF2Y0dWeVlYUnZjaTF1YzRJM2FXNTANClpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXdaWEpoZEc5eUxXNXoNCkxuTjJZNEpGYVc1MFpYSnVZV3d0ZDJWaWJHOW5hV010YjNCbGNtRjBiM0l0YzNaakxuZGxZbXh2WjJsakxXOXcNClpYSmhkRzl5TFc1ekxuTjJZeTVqYkhWemRHVnlMbXh2WTJGc01BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQUENCjdzMnB5dk1FSG9lTGR6ZGN1NHk1VmtBZWdiVHlTR2MwTWUwUkR0elNBUVB6N0lCQllNLzg0R2ZkZGlmVWxwSkUNCnM1RGdmOWcxb2hzN0JBWDNZNlFOTVI3c2tDQ2o2OEUzK0RRSkpBUUUvbXhEak9mTnBvUGl3Z1QzMUcxSzdmelANCk40OUQ4Y09VZjNyTmVDaWhvREV6dDRROFlNb0RybHd6WTNzVnRDZXRLdzV3d1h1Ry9FakI2dEhwL2FXeGFSTE8NCndmMVN6RmVBTllmMDdrVkl4ZE5wbFV5RFdLYVN4VUhEYnhvM3d0YzBaQm1sU1VYNEFCZlRtOU1HZzZOcGp1ZlkNClpEOUVDNE40T2xGU0REYmpLSXBHL0Z0RTJXdHR4cHBrbGZLSDdzS3I0V1JlY2hCclBsNk9MNDVJUlFCdkVSZDkNCnhSZlNVWEJ2bFQ5Q3BHcG1ZZmN4Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
NODEMGR_HOME=/u01/nodemanager
SHLVL=1
HOME=/home/oracle
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_7001_TCP_ADDR=10.96.213.13
SERVER_NAME=admin-server
SHUTDOWN_TYPE=Graceful
MANAGED_SERVER_NAME=
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_SERVICE_PORT_HTTPS=443
ADMIN_USERNAME=
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_SERVICE_PORT=30012
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_7001_TCP_PORT=7001
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_PORT_30012_TCP=tcp://10.96.213.13:30012
SHUTDOWN_TIMEOUT=30
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
ADMIN_PASSWORD=
ORACLE_HOME=/u01/oracle
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
WLS_K8S_DOMAIN_ADMIN_SERVER_EXTERNAL_SERVICE_PORT_T3CHANNEL=30012
_=/usr/bin/env
```
After those two shell scripts created then we need to copy those to the admin-server pod:
```
kubectl cp scalingActionUp.sh wls-k8s-domain-admin-server:/tmp -n wls-k8s-domain-ns
kubectl cp scalingActionDown.sh wls-k8s-domain-admin-server:/tmp -n wls-k8s-domain-ns
```
Then we need to login again to the admin-server pod again to put that in the appropriate directory:
```
kubectl exec -it wls-k8s-domain-admin-server -n wls-k8s-domain-ns -- /bin/bash
mkdir -p bin/scripts
cd bin/scripts
cp /tmp/scalingActionUp.sh .
cp /tmp/scalingActionDown.sh .
```
Then now we need to configure the WLDF part from WebLogic Console 
