#!/bin/bash
#### Export the following environment variables before running this script
# Infra cluster refers to the Cluster hosting the Hypershift cluster
# Tenant cluster refers to the hypershift cluster 
#
# INFRA_CLUSTER_KUBECONFIG <- path to the Infra cluster kubeconfig file
# INFRA_CLUSTER_TENANT_NAMESPACE  <- The namespace on the Infra cluster where the Tenant cluster is deployed to 
# INFRA_STORAGE_CLASS_NAME <- The storage class that the kubevirt csi will map to
#
# TENANT_CLUSTER_NAME
# TENANT_CLUSTER_KUBEECONFIG <- path to the Tenant cluster kubeconfig file
# 

kubectl --kubeconfig $INFRA_CLUSTER_KUBECONFIG apply -f ./infra-cluster-service-account.yaml -n $INFRA_CLUSTER_TENANT_NAMESPACE

CFG_SECRET_NAME=$(kubectl --kubeconfig $INFRA_CLUSTER_KUBECONFIG -n clusters-$TENANT_CLUSTER_NAME get serviceaccount/kubevirt-csi -o jsonpath='{.secrets[0].name}')
TOKEN_NAME=$(kubectl --kubeconfig $INFRA_CLUSTER_KUBECONFIG -n clusters-$TENANT_CLUSTER_NAME get secret $CFG_SECRET_NAME -o jsonpath='{.metadata.ownerReferences[0].name}')
export CA_CRT=$(kubectl --kubeconfig $INFRA_CLUSTER_KUBECONFIG -n clusters-$TENANT_CLUSTER_NAME get secret $TOKEN_NAME -o json | jq '.data["ca.crt"]' | xargs echo)
export TOKEN=$(kubectl --kubeconfig $INFRA_CLUSTER_KUBECONFIG -n clusters-$TENANT_CLUSTER_NAME get secret $TOKEN_NAME -o json | jq '.data["token"]' | xargs echo | base64 -d)

KUBECONFIG_CONTENT=$(kubectl --kubeconfig $INFRA_CLUSTER_KUBECONFIG config view -o json)
export CURRENT_CONTEXT=$(echo $KUBECONFIG_CONTENT | jq '.["current-context"]' | xargs echo)
export CLUSTER_SPEC_NAME=$(echo $KUBECONFIG_CONTENT | jq -c '.contexts' | jq -c '.[] | select( .name == env.CURRENT_CONTEXT )' | jq '.context.cluster' | xargs echo)
export SERVER_URL=$(echo $KUBECONFIG_CONTENT | jq -c '.clusters' | jq -c '.[] | select( .name == env.CLUSTER_SPEC_NAME )' | jq '.cluster.server' | xargs echo)
export INFRA_KUBEVIRT_CSI_SERVICE_KUBECONFIG_BASE64=$(envsubst < ./tenant-csi-deploy-kustomize/base/infra-cluster-kubeconfig-template.yaml | base64 -w 0)


envsubst <  ./tenant-csi-deploy-kustomize/base/050-infra-cluster-credentials-template.yaml > ./tenant-csi-deploy-kustomize/base/050-infra-cluster-credentials.yaml
envsubst <  ./tenant-csi-deploy-kustomize/base/060-infra-cluster-driver-config-template.yaml > ./tenant-csi-deploy-kustomize/base/060-infra-cluster-driver-config.yaml
envsubst <  ./tenant-csi-deploy-kustomize/base/070-storageclass-template.yaml > ./tenant-csi-deploy-kustomize/base/070-storageclass.yaml


kubectl --kubeconfig $TENANT_CLUSTER_KUBEECONFIG kustomize ./tenant-csi-deploy-kustomize/base | oc apply -f - 

## cleanup
rm -f ./tenant-csi-deploy-kustomize/base/050-infra-cluster-credentials.yaml
rm -f ./tenant-csi-deploy-kustomize/base/060-infra-cluster-driver-config.yaml
rm -f ./tenant-csi-deploy-kustomize/base/070-storageclass.yaml

echo Done!