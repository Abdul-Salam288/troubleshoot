**Note: Ensure if any operation is performed in AKS cluster then before proceeding wait for it to complete or abort first and then start new**

**Note: Ensure the New Node Pool with one node can be created in Production Cluster**

**Note: az aks update command use with caution as it will reconcile complete cluster**

Below Command will help in checking the current operation and abort if required.
```
az aks show --resource-group $RG --name $CLUSTER --query "provisioningState"
az aks operation-abort --resource-group $RG --name $CLUSTER
```

# Planning Phase

**1. Verify and validate the release notes using below links** 
- Azure tracker                                 https://releases.aks.azure.com/KubernetesVersions
- Kubernetes Version release notes              https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG
- AKS components breaking changes by version    https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli

Note: AKS also give an option to enable long time support (LTS) for older version

_How to Quickly Scan the Changelog (TIPS):-_

* Instead of reading the whole file, secarh inside it for:
  - Deprecated
  - Removed
  - Breaking
  - Action Required

  

**2. Networking**

- Verify how the network is configured using Azure CNI or Azure CNI node subnet
  - verify network plugin using azure CLI
```
az aks show --resource-group $RG --name $CLUSTER --query networkProfile

        {
        "advancedNetworking": null,
        "dnsServiceIp": "172.21.0.10",
        "ipFamilies": [
            "IPv4"
        ],
        "loadBalancerProfile": {
            "allocatedOutboundPorts": null,
            "backendPoolType": "nodeIPConfiguration",
            "effectiveOutboundIPs": [
            {
                "id": "/subscriptions/xxxxx/resourceGroups/RG/providers/Microsoft.Network/publicIPAddresses/xxxxxx",
                "resourceGroup": "RG"
            }
            ],
            "enableMultipleStandardLoadBalancers": null,
            "idleTimeoutInMinutes": null,
            "managedOutboundIPs": {
            "count": 1,
            "countIpv6": null
            },
            "outboundIPs": null,
            "outboundIpPrefixes": null
        },
        "loadBalancerSku": "Standard",
        "natGatewayProfile": null,
        "networkDataplane": "azure",
        "networkMode": null,
        "networkPlugin": "azure",
        "networkPluginMode": null,
        "networkPolicy": "none",
        "outboundType": "loadBalancer",
        "podCidr": null,
        "podCidrs": null,
        "serviceCidr": "172.21.0.0/22",
        "serviceCidrs": [
            "172.21.0.0/22"
        ],
        "staticEgressGatewayProfile": null
        }
```

- if Azure CNI node subnet, verify the vnet subnet associated to AKS have enough IPs available to support surge node which will be used to upgrade the nodes without service disruption

  

_How to calculate the IPs used by nodes in Subnet of Vnet_

1. Verify the total number of nodes available in AKS cluster -- kubectl get nodes
1. Verify the max pods could be scheduled in each node -- kubectl describe node <node-name>
1. Calculate it by formula -- (number of nodes) * max pods

  

_for example: -_

    if AKS cluster has 2 nodes and max pods can be scheduled in each node is 30 then IP utilised in the subnet would be 2*30 = 60 IP

for 1 max surge node, in my scenario, available IPs should be available is 31 but ensure to check the node capacity and IPs allocation 

  

_Alternate options: -_

Via **Azure Portal** -- navigate to Vnet -> Subnet -> GUI will shows the available IP for that subnet (ensure this subnet is associated to node)

Via **Azure CLI**    -- az network vnet subnet show --resource-group $RG --vnet-name $vnet-name --name $subnet-name --query "ipConfigurations[].id" -o tsv | wc -l

**3. Verify the URL is allowed via nodepool**

Package used for validating the URL in Linux:- wget, curl, nslookup, dig, nc -vz, openssl

Microsoft URL should be allowed:-  https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress#azure-global-required-network-rules

- How to Verify the URL

    a. You can create a pod and validate the URL

        kubectl debug node/aks-nodepool2-29651852-vmss000000 -it --image=mcr.microsoft.com/azurelinux/busybox:1.36

    b. You can get the network rich image and push to the aks attached ACR and create a POD out of that image

        example:
        apiVersion: v1
        kind: Pod
        metadata:
        name: network-debug
        namespace: debug
        spec:
        containers:
        - name: debug
            image: internalacr.azurecr.io/network-debug:latest
            command: ["sleep", "3600"]
            securityContext:
            capabilities:
                add: ["NET_ADMIN", "NET_RAW"]
        restartPolicy: Never


**Note: Ensure by creating a dummy nodepool in various environment if you have an option because it will ensure nodes can be created or not or there is any block**

**4. Verify the Addon(plugins) Profiles used in AKS**
```
az aks show --resource-group $RG --name $CLUSTER --query addonProfiles
{
  "azureKeyvaultSecretsProvider": {
    "config": {
      "enableSecretRotation": "false",
      "rotationPollInterval": "2m"
    },
    "enabled": true,
    "identity": null
  },
  "azurepolicy": {
    "config": null,
    "enabled": true,
    "identity": null
  },
  "omsagent": {
    "config": {
      "logAnalyticsWorkspaceResourceID": "/subscriptions/xxxxx/resourceGroups/DefaultResourceGroup-EUS/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-xxxx-EUS",
      "useAADAuth": "false"
    },
    "enabled": true,
    "identity": null
  }
}
```

**5. Verify the Azure Policy**

- To validate the Azure policy is enabled or not?
```
az aks show -g $RG -n $CLUSTER --query addonProfiles.azurepolicy
{
  "config": null,
  "enabled": true,
  "identity": null
}
```

- To validate the Pod is running and check the logs of gatekeepers [Optinal]

```
kubectl get pods -n gatekeeper-system
NAME                                     READY   STATUS    RESTARTS   AGE
gatekeeper-audit-xxxxxxxxxxxxxxxx        1/1     Running   0          21h
gatekeeper-controller-xxxxxxxxxxxxxxxx   1/1     Running   0          22h
gatekeeper-controller-xxxxxxxxxxxxxxxx   1/1     Running   0          21h

kubectl logs -n gatekeeper-system -l control-plane=audit-controllers
```

- To validate the constraints available and verify the enforcement and rules in AKS for Pods

```
kubectl get constrainttemplates
kubectl get constraints
kubectl get constrains <name>
kubectl describe <constraints-name>
```

- Verify also the Azure policy for vmss or virtual machine, this will impact directly the nodepool creation



**6. Verify the storage plugins**

* Storage plugins run as CSI drivers:-   kubectl get csidrivers

**7. Verify the current node image version (which is part of upgrading process when we upgrade the kubernetes version)**
You could check what node image will be updated using this link -- https://releases.aks.azure.com/Ubuntu
```
az aks nodepool get-upgrades --resource-group $RG --cluster-name $CLUSTER --nodepool-name <node-pool-name>                           
{                
  "id": "/subscriptions/xxxxxxxxx/resourcegroups/RG1234567890099988888666/providers/Microsoft.ContainerService/managedClusters/aksclusters/agentPools/nodepool1/upgradeProfiles/default",
  "kubernetesVersion": "1.30.10",
  "latestNodeImageVersion": "AKSUbuntu-2204gen2containerd-202602.13.5",
  "name": "default",
  "osType": "Linux",
  "resourceGroup": "RG1234567890099988888666",
  "type": "Microsoft.ContainerService/managedClusters/agentPools/upgradeProfiles",
  "upgrades": null
}
```

**8. Upgrade availability**

1. Verify the kubernetes upgrade available in AKS

```
RG=""
CLUSTER=""
az aks get-upgrades --resource-group $RG --name $CLUSTER --output table
Name     ResourceGroup            MasterVersion    Upgrades
-------  -----------------------  ---------------  ------------------------------------------------------------------------------------------------
default  RG1234567890099988888666  1.30.10          1.31.13, 1.32.0, 1.32.1, 1.32.2, 1.32.3, 1.32.4, 1.32.5, 1.32.6, 1.32.7, 1.32.8, 1.32.9, 1.32.10
```
2. If Istio is configured in the AKS, then ensure istio is supported by kubernetes version
```
az aks mesh get-upgrades --resource-group $RG --name $CLUSTER
{
  "compatibleWith": [
    {
      "name": "KubernetesOfficial",
      "versions": [
        "1.29",
        "1.30",
        "1.31",
        "1.32",
        "1.33"
      ]
    }
  ],
  "revision": "asm-1-25",
  "upgrades": null
}
```
**9. Max Surge Setting**

The default max-surge value is 1 node.
```
az aks nodepool show --resource-group $RG --cluster-name $CLUSTER --name nodepool1 --query "upgradeSettings"                         
{
  "drainTimeoutInMinutes": 30,
  "maxSurge": null,                 <-- Null points to max-surge is 1>
  "maxUnavailable": "0",
  "nodeSoakDurationInMinutes": null,
  "undrainableNodeBehavior": null
}
```
**8. Ensure kubent is installed and configured**

This is used to check the kubectl api resources currently used in AKS is not depricated
1. To install the kebent
```
curl -L --ssl-no-revoke https://git.io/install-kubent
sh kubent.sh
```
2. Verify the depricated api resource using kubent
```
kubent --target-version 1.31.13
9:42AM INF >>> Kube No Trouble `kubent` <<<
9:42AM INF version 0.7.3 (git sha 57480c07b3f91238f12a35d0ec88d9368aae99aa)
9:42AM INF Initializing collectors and retrieving data
9:42AM INF Target K8s version is 1.31.13
9:42AM INF Retrieved 144 resources from collector name=Cluster
9:42AM INF Retrieved 298 resources from collector name="Helm v3"
9:42AM INF Loaded ruleset name=custom.rego.tmpl
9:42AM INF Loaded ruleset name=deprecated-1-16.rego
9:42AM INF Loaded ruleset name=deprecated-1-22.rego
9:42AM INF Loaded ruleset name=deprecated-1-25.rego
9:42AM INF Loaded ruleset name=deprecated-1-26.rego
9:42AM INF Loaded ruleset name=deprecated-1-27.rego
9:42AM INF Loaded ruleset name=deprecated-1-29.rego
9:42AM INF Loaded ruleset name=deprecated-1-32.rego
9:42AM INF Loaded ruleset name=deprecated-future.rego
```

**9. Ensure IstioCTL is installed and configured**

```
curl -L --ssl-no-revoke https://istio.io/downloadIstio     <-- download the script
sh isito.sh 
ISTIO_VERSION=1.25.0 sh istio.sh

Downloading istio-1.25.0 from https://github.com/istio/istio/releases/download/1.25.0/istio-1.25.0-linux-amd64.tar.gz ...

Istio 1.25.0 download complete!

The Istio release carhive has been downloaded to the istio-1.25.0 directory.

To configure the istioctl client tool for your workstation,
add the /home/madhu/istio-1.25.0/bin directory to your environment path variable with:
         export PATH="$PATH:/home/madhu/istio-1.25.0/bin"
```


# Pre Checks
**1. AKS health and Pod health**

```
kubectl get nodes
NAME                                STATUS   ROLES    AGE    VERSION
aks-nodepool1-21312257-vmss00001o   Ready    <none>   325d   v1.30.10
aks-nodepool1-21312257-vmss00001u   Ready    <none>   278d   v1.30.10
aks-nodepool1-21312257-vmss00001x   Ready    <none>   262d   v1.30.10
aks-nodepool1-21312257-vmss000020   Ready    <none>   205d   v1.30.10
aks-nodepool2-93781571-vmss000000   Ready    <none>   343d   v1.30.10
aks-nodepool2-93781571-vmss000001   Ready    <none>   343d   v1.30.10
aks-nodepool2-93781571-vmss000002   Ready    <none>   343d   v1.30.10
aks-simpool-26417791-vmss000000     Ready    <none>   332d   v1.30.10

kubectl get pods -A | grep -E 'CrashLoop|Error|Init'
kubectl get pods -n kube-system
```

**2. Control plane + node pool skew**

```
kubectl version
Client Version: v1.34.0
Kustomize Version: v5.7.1
Server Version: v1.30.10
Warning: version difference between client (1.34) and server (1.30) exceeds the supported minor version skew of +/-1
```
  

**3. verify the detailed data about the nodes (optional)**
```
kubectl get node -o wide
NAME                                STATUS   ROLES    AGE    VERSION    INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
aks-nodepool1-21312257-vmss00001o   Ready    <none>   325d   v1.30.10   10.255.133.40    <none>        Ubuntu 22.04.5 LTS   5.15.0-1082-azure   containerd://1.7.26-1
aks-nodepool1-21312257-vmss00001u   Ready    <none>   278d   v1.30.10   10.255.133.181   <none>        Ubuntu 22.04.5 LTS   5.15.0-1082-azure   containerd://1.7.26-1
aks-nodepool1-21312257-vmss00001x   Ready    <none>   262d   v1.30.10   10.255.133.10    <none>        Ubuntu 22.04.5 LTS   5.15.0-1082-azure   containerd://1.7.26-1
aks-nodepool1-21312257-vmss000020   Ready    <none>   205d   v1.30.10   10.255.133.100   <none>        Ubuntu 22.04.5 LTS   5.15.0-1082-azure   containerd://1.7.26-1
aks-nodepool2-93781571-vmss000000   Ready    <none>   343d   v1.30.10   10.255.133.65    <none>        Ubuntu 22.04.5 LTS   5.15.0-1082-azure   containerd://1.7.26-1
aks-nodepool2-93781571-vmss000001   Ready    <none>   343d   v1.30.10   10.255.133.123   <none>        Ubuntu 22.04.5 LTS   5.15.0-1082-azure   containerd://1.7.26-1
aks-nodepool2-93781571-vmss000002   Ready    <none>   343d   v1.30.10   10.255.133.152   <none>        Ubuntu 22.04.5 LTS   5.15.0-1082-azure   containerd://1.7.26-1
aks-simpool-26417791-vmss000000     Ready    <none>   332d   v1.30.10   10.255.133.255   <none>        Ubuntu 22.04.5 LTS   5.15.0-1084-azure   containerd://1.7.27-1
```
  
```
kubectl describe node aks-nodepool1-21312257-vmss00001o | grep -A15 Type   -- verifying details info if needed
  Type                          Status  LastHeartbeatTime                 LastTransitionTime                Reason                          Message

  ----                          ------  -----------------                 ------------------                ------                          -------
  FilesystemCorruptionProblem   False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   FilesystemIsOK                  Filesystem is healthy
  FrequentKubeletRestart        False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   NoFrequentKubeletRestart        kubelet is functioning properly
  KernelDeadlock                False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   KernelHasNoDeadlock             kernel has no deadlock
  VMEventScheduled              False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 03 Mar 2026 11:39:08 +0000   NoVMEventScheduled              VM has no scheduled event
  FrequentUnregisterNetDevice   False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   NoFrequentUnregisterNetDevice   node is functioning properly
  ContainerRuntimeProblem       False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   ContainerRuntimeIsUp            container runtime service is up
  KubeletProblem                False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   KubeletIsUp                     kubelet service is up
  FrequentContainerdRestart     False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   NoFrequentContainerdRestart     containerd is functioning properly
  ReadonlyFilesystem            False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   FilesystemIsNotReadOnly         Filesystem is not read-only
  FrequentDockerRestart         False   Sun, 08 Mar 2026 21:53:53 +0000   Tue, 24 Feb 2026 20:28:44 +0000   NoFrequentDockerRestart         docker is functioning properly
  MemoryPressure                False   Sun, 08 Mar 2026 21:53:39 +0000   Fri, 11 Apr 2025 13:10:36 +0000   KubeletHasSufficientMemory      kubelet has sufficient memory available
  DiskPressure                  False   Sun, 08 Mar 2026 21:53:39 +0000   Fri, 11 Apr 2025 13:10:36 +0000   KubeletHasNoDiskPressure        kubelet has no disk pressure
  PIDPressure                   False   Sun, 08 Mar 2026 21:53:39 +0000   Fri, 11 Apr 2025 13:10:36 +0000   KubeletHasSufficientPID         kubelet has sufficient PID available
  Ready                         True    Sun, 08 Mar 2026 21:53:39 +0000   Fri, 11 Apr 2025 13:10:37 +0000   KubeletReady                    kubelet is posting ready status
```

**4. Verify the pods availability in node (optoinal) -- only used when we want to optimize the IP address**
```
kubectl describe node <node-name> | grep -A5 "Non-terminated Pods"
```

**5. Istio control plane health**
```
kubectl get pods -n aks-istio-system
NAME                               READY   STATUS    RESTARTS   AGE
istiod-asm-1-25-xxxxxxxxxx-gh4kr   1/1     Running   0          5d11h
istiod-asm-1-25-xxxxxxxxxx-vlbzb   1/1     Running   0          5d11h

kubectl get pods -n aks-istio-ingress
NAME                                                          READY   STATUS    RESTARTS   AGE
aks-istio-ingressgateway-internal-asm-1-25-xxxxxxxxxx-krwpg   1/1     Running   0          5d11h
aks-istio-ingressgateway-internal-asm-1-25-xxxxxxxxxx-xx49b   1/1     Running   0          5d11h
```

**6. Istio analyzers** 
- Fix if any error or validate this error does not cause any issue.
```
istioctl analyze --all-namespaces
```
**7. STRICT mTLS + injection safety**
```
kubectl get peerauthentication -A
NAMESPACE   NAME      MODE     AGE
car         default   STRICT   2y225d
```
  

**8. Proxy sync status**
```
istioctl proxy-status --istioNamespace aks-istio-system
NAME                                                                              CLUSTER        CDS                LDS                EDS                RDS                ECDS        ISTIOD                               VERSION
aks-istio-ingressgateway-internal-asm-1-25-55f94fc5cb-krwpg.aks-istio-ingress     Kubernetes     SYNCED (6m51s)     SYNCED (6m51s)     SYNCED (6m51s)     SYNCED (6m51s)     IGNORED     istiod-asm-1-25-xxxxxxxxx-gh4kr     1.25.5
```

**9. Pod Disruption Budgets (VERY IMPORTANT)**
```
sesadm@car ~ → kubectl get pdb -A
NAMESPACE           NAME                                MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
aks-istio-ingress   aks-istio-ingressgateway-internal   1               N/A               1                     2y221d
aks-istio-system    istiod-asm-1-25                     1               N/A               1                     273d
gatekeeper-system   gatekeeper-controller-manager-pdb   1               N/A               1                     205d
kube-system         coredns-pdb                         1               N/A               2                     2y226d
kube-system         konnectivity-agent                  1               N/A               1                     2y226d
kube-system         metrics-server-pdb                  1               N/A               1                     2y226d
```

**10. Optional Check Webhooks and daemonset and verify appropriate pod is healthy**
```
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
kubectl get daemonsets -A
```

**11. Fetch the pods logs for each service**

```
    kubectl logs <pod-name> -n <ns>
``` 

**12. Verify the car UI and Pgadmin**
  
- Verify the Application via Browser

# Implementation Plan

### Process
- Upgrade execution order (IMPORTANT)
1️⃣ Control plane only → wait → validate
2️⃣ Node pools one by one
3️⃣ Validate after each pool

- Always upgrade in this order:
1️⃣ System node pool
2️⃣ Stateless user pools
3️⃣ Stateful / critical pools (last)

**1. Verify the deprecated API resources**
```
kubent --target-version 1.31.13
9:42AM INF >>> Kube No Trouble `kubent` <<<
9:42AM INF version 0.7.3 (git sha 57480c07b3f91238f12a35d0ec88d9368aae99aa)
9:42AM INF Initializing collectors and retrieving data
9:42AM INF Target Ksversion is 1.31.13
9:42AM INF Retrieved 144 resources from collector name=Cluster
9:42AM INF Retrieved 298 resources from collector name="Helm v3"
9:42AM INF Loadeduleset name=custom.rego.tmpl
9:42AM INF Loaded ruleset name=deprecated-1-16.rego
9:42AM INF Loaded ruleset name=deprecated-1-22.rego
9:42AM INF Loaded ruleset name=deprecated-1-25.rego
9:42AM INF Loaded ruleset name=deprecated-1-26.rego
9:42AM INF Loaded ruleset name=deprecated-1-27.rego
9:42AM INF Loaded ruleset name=deprecated-1-29.rego
9:42AM INF Loaded ruleset name=deprecated-1-32.rego
9:42AM INF Loaded ruleset name=deprecated-future.rego
```

**2. Upgrade the control cluster first**
```
az aks upgrade --resource-group $RG --name $CLUSTER --kubernetes-version <version-number> --control-plane-only
```

- verify
```
az aks show --resource-group $RG --name $CLUSTER --output table
```
  

**3. Upgrade the nodepool**

_Note: drain, cordon and uncordon is taken care by AKS upgrade command_
```
az aks nodepool upgrade --resource-group $RG --cluster-name $CLUSTER --name $node-name --kubernetes-version <version-number> --max-surge 1
```
- verify nodepool version
```
az aks nodepool list --resource-group $RG --cluster-name $CLUSTER --query "[].{Name:name,Version:orchestratorVersion}" --output table
```
### monitor
- Watch the upgrade
```
watch kubectl get nodes
kubectl get events -A --sort-by=.lastTimestamp
kubectl get events -n car
```

# Post Checks
**1. Verify the control plan**
```
az aks show --resource-group $RG --name $CLUSTER --output table
Name         Location    ResourceGroup            KubernetesVersion    CurrentKubernetesVersion    ProvisioningState    Fqdn

-----------  ----------  -----------------------  -------------------  --------------------------  -------------------  ---------------------------------------------------------------------------------------

aksclusters  eastus      RG1234567890099988888666  1.31.13              1.31.13                     Succeeded            akscluster-rsg-mpws1car-eus-e3ab28-4opur3k6.aks-mpws1car-t.privatelink.eastus.azmk8s.io
```
**2. Verify the nodes**
```
kubectl get nodes
NAME                                STATUS   ROLES    AGE     VERSION
aks-nodepool1-21312257-vmss00001o   Ready    <none>   59m     v1.31.13
aks-nodepool1-21312257-vmss00001u   Ready    <none>   54m     v1.31.13
aks-nodepool1-21312257-vmss00001x   Ready    <none>   49m     v1.31.13
aks-nodepool1-21312257-vmss000020   Ready    <none>   44m     v1.31.13
aks-nodepool2-93781571-vmss000000   Ready    <none>   9m2s    v1.31.13
aks-nodepool2-93781571-vmss000001   Ready    <none>   4m55s   v1.31.13
aks-nodepool2-93781571-vmss000002   Ready    <none>   79s     v1.31.13
```
**3. Verify the pods**
```
07:48:57 sesadm@car ~ →  kubectl get pods -A -o wide
NAMESPACE           NAME                                                          READY   STATUS             RESTARTS         AGE     IP               NODE                                NOMINATED NODE   READINESS GATES
agents              deploy-s1-classic-deploy-agent-xxxxxxxxxx-p8tqn               1/1     Running            0                44m     10.255.133.108   aks-nodepool1-21312257-vmss000020   <none>           <none>
agents              deploy-s1-deploy-agent-xxxxxxxxxx-9kdpz                       0/1     CrashLoopBackOff   10 (2m43s ago)   29m     10.255.133.102   aks-nodepool1-21312257-vmss000020   <none>           <none>
aks-istio-ingress   aks-istio-ingressgateway-internal-asm-1-25-xxxxxxxxxx-mc7h7   1/1     Running            0                54m     10.255.133.195   aks-nodepool1-21312257-vmss00001u   <none>           <none>
aks-istio-ingress   aks-istio-ingressgateway-internal-asm-1-25-xxxxxxxxxx-svm8x   1/1     Running            0                49m     10.255.133.51    aks-nodepool1-21312257-vmss00001o   <none>           <none>
aks-istio-system    istiod-asm-1-25-xxxxxxxxxx-j9gdc                              1/1     Running            0                49m     10.255.133.186   aks-nodepool1-21312257-vmss00001u   <none>           <none>
aks-istio-system    istiod-asm-1-25-xxxxxxxxxx-ssdg8                              1/1     Running            0                49m     10.255.133.11    aks-nodepool1-21312257-vmss00001x   <none>           <none>

kubectl get pods -A | grep -E 'CrashLoop|Error|Init'
agents              deploy-s1-deploy-agent-xxxxxxxxxx-9kdpz                       0/1     CrashLoopBackOff   10 (5m2s ago)   31m
```
**4. Verify the CSI drivers**
```
kubectl get csidrivers
NAME                       ATTACHREQUIRED   PODINFOONMOUNT   STORAGECAPACITY   TOKENREQUESTS                REQUIRESREPUBLISH   MODES                  AGE
disk.csi.azure.com         true             false            false             <unset>                      false               Persistent             2y233d
file.csi.azure.com         false            true             false             api://AzureADTokenExchange   false               Persistent,Ephemeral   2y233d
secrets-store.csi.k8s.io   false            true             false             api://AzureADTokenExchange   false               Ephemeral              2y228d
```
**5. Istio Analyzer**
```
istioctl analyze --all-namespaces
```
  

**6. STRICT mTLS + injection safety**
```
kubectl get peerauthentication -A
NAMESPACE   NAME      MODE     AGE
car         default   STRICT   2y225d
```
**7. Istio proxy status**
```
istioctl proxy-status --istioNamespace aks-istio-system
NAME                                                                              CLUSTER        CDS                LDS                EDS                RDS                ECDS        ISTIOD                               VERSION
aks-istio-ingressgateway-internal-asm-1-25-xxxxxxxxx-mc7h7.aks-istio-ingress     Kubernetes     SYNCED (20m)       SYNCED (20m)       SYNCED (5m40s)     SYNCED (20m)       IGNORED     istiod-asm-1-25-xxxxxxxxxx-j9gdc     1.25.5
aks-istio-ingressgateway-internal-asm-1-25-55f94fc5cb-svm8x.aks-istio-ingress     Kubernetes     SYNCED (25m)       SYNCED (25m)       SYNCED (5m40s)     SYNCED (25m)       IGNORED     istiod-asm-1-25-xxxxxxxxxx-ssdg8     1.25.5
carrier-coordinator-69b6867d75-mrb4l.car                                          Kubernetes     SYNCED (24m)       SYNCED (24m)       SYNCED (5m40s)     SYNCED (24m)       IGNORED     istiod-asm-1-25-xxxxxxxxxx-j9gdc     1.25.5
clu-5f54844fbc-qnfrw.car                                                          Kubernetes     SYNCED (8m57s)     SYNCED (8m57s)     SYNCED (5m40s)     SYNCED (8m57s)     IGNORED     istiod-asm-1-25-xxxxxxxxxxx-j9gdc     1.25.5
```
**8. Istio controller health**
```
kubectl get pods -n aks-istio-system
NAME                               READY   STATUS    RESTARTS   AGE
istiod-asm-1-25-xxxxxxxxxx-9ktkj   1/1     Running   0          24m
istiod-asm-1-25-xxxxxxxxxx-cdfd4   1/1     Running   0          30m
08:46:17 sesadm@car ~ → kubectl get pods -n aks-istio-ingress
NAME                                                          READY   STATUS    RESTARTS   AGE
aks-istio-ingressgateway-internal-asm-1-25-xxxxxxxxxx-8tzv6   1/1     Running   0          24m
aks-istio-ingressgateway-internal-asm-1-25-xxxxxxxxxx-r84mf   1/1     Running   0          24m
```

**9. Fetch the pods logs for each service**

```
    kubectl logs <pod-name> -n <ns>
``` 

**10. Verify the car UI and Pgadmin**
  
- Verify the Application via Browser
