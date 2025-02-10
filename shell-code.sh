Cockroach DB backup for Hashicorp Vault

restore the whole database:
RESTORE DATABASE database FROM LATEST IN 's3://105250-0000ie-pcore-cdb-backups-src/cockroach-backup?AUTH=implicit&AWS_REGION=eu-west-1' WITH "+
"kms = 'aws:///arn:aws:kms:eu-west-1:774112052821:alias/105250-0000ie-pcore-cockroach-cmk?AUTH=implicit&REGION=eu-west-1';




save it as s3 bucket:

kubectl -n 105250-cockroach-eu-west-1 exec -it cockroach-0 -- bash

cd cockroach-data

ZIP_START_DATE=$(date -d '1 hour ago' "+%Y-%m-%d %H:%M:%S")
ZIP_START_DATE=$(date -d '1 hour ago' "2024-5-7 4:33:0")

TSDUMP_START_DATE=$(date -d '24 hour ago' "+%Y-%m-%d %H:%M:%S")
TSDUMP_START_DATE=$(date -d '24 hour ago' "2024-5-6 5:33:0")

END_DATE=$(date "2024-5-7 6:33:0")
FILE_NAME=$(date "2024-5-7 5:33:0")

cockroach debug zip debug-${FILE_NAME}.zip --certs-dir=../cockroach-certs-copy --files-from "${ZIP_START_DATE}" --files-until "${END_DATE}"
cockroach debug tsdump --certs-dir=../cockroach-certs-copy --format=raw --from "${TSDUMP_START_DATE}" --to "${END_DATE}" | gzip > tsdump-${FILE_NAME}.gob.gz

BUCKET_NAME="105250-0000ie-pcore-cdb-backups-src"

aws s3 cp tsdump-${FILE_NAME}.gob.gz s3://${BUCKET_NAME}/tsdump-${FILE_NAME}.gob.gz
aws s3 cp debug-${FILE_NAME}.zip s3://${BUCKET_NAME}/debug-${FILE_NAME}.zip

aws s3 ls --human-readable s3://${BUCKET_NAME}/debug-${FILE_NAME}.zip
aws s3 ls --human-readable s3://${BUCKET_NAME}/tsdump-${FILE_NAME}.gob.gz

rm debug-${FILE_NAME}.zip
rm tsdump-${FILE_NAME}.gob.gz



Created by Babak Habibnejad Gohardani, last modified on May 09, 2024
1. kubectl exec -it  -n 105250-core-hault hault-0 sh : go inside hashicorp-vault pod 

2. export VAULT_SKIP_VERIFY=true

3. export VAULT_TOKEN="XXXXX" : get this token from aws console => Amazon S3/Buckets/105250-0000ie-Xcore-hault-unseal-keys/vault-root

4. cd /tmp



** open another terminal tab, keep first one open **

5. kubectl get pod -n 105250-vault-operators : get name of the crown operator pod

5. kubectl cp -n 105250-vault-operators crown-operator-XXXXX:/var/run/secrets/kubernetes.io/serviceaccount/..data/ca.crt  ./cert_vault-operator-sa : copy the certificate locally from crown operator

6. kubectl cp -n 105250-vault-operators crown-operator-XXXXX:/var/run/secrets/kubernetes.io/serviceaccount/..data/token  ./token_vault-operator-sa : copy the token locally from crown operator

7. kubectl cp cert_vault-operator-sa -n 105250-core-hault hault-0:/tmp/cert_vault-operator-sa -c vault  : copy cert to hashicorp vault pod

8. kubectl cp token_vault-operator-sa -n 105250-core-hault hault-0:/tmp/token_vault-operator-sa -c vault : copy token to hashicorp vault pod

9. kubectl exec -it vault-tools-679f85d45f-6699v bash -n 105250-vault-operators  : log into the vault-tools pod

10. kubectl cluster-info : find what ip address the kubernetes master is running at



** in first terminal tab **

11. ls : should see both token and certificate in /tmp folder

12. export VAULT_SA_NAME=vault-operator-sa

13. export K8S_HOST="https://10.100.0.1:443"  : get this from step 10

14. export SA_JWT_TOKEN=$(cat token_vault-operator-sa)

15. export SA_CA_CRT=$(cat cert_vault-operator-sa)

16. vi token_vault-operator-sa : you can edit the cert or token here for experiments, edit any random character, it should break the file

17. echo $VAULT_SA_NAME | echo $K8S_HOST | echo $SA_JWT_TOKEN | echo $SA_CA_CRT  : makes sure all these variables have values

18. vault write auth/kubernetes/config \

        token_reviewer_jwt="$SA_JWT_TOKEN" \

        kubernetes_host="$K8S_HOST" \

        kubernetes_ca_cert="$SA_CA_CRT"



** in second terminal tab **

19. cd /tmp

20. ls : should see vaultctl file, you can control Hashicorp vault with this file

21. ./vaultctl restart --context inCluster --namespace 105250-core-vault  : restart hashicorp vault, might throw an error. repeat until successful 

22. kubectl get pod -n 105250-core-vault : several pods should have initError and CrashBackLoopOff errors, pick one of them

22. kubectl describe pod vault-postings-enrichment-processor-56f9f4c6c9-t279c -n 105250-core-vault : check one of the failing pods, and it's init-container 

23. kubectl logs -n 105250-core-vault vault-postings-enrichment-processor-56f9f4c6c9-t279c -c init-teller : check init-container logs to see the error, it might look similar to this:



{"file":"infrastructure/aws_account_bootstrap/hault/teller/main.go:38","func":"main.main","kind":"application","level":"info","msg":"\u0026{SecretsPath:/etc/hault ConfigPath:/etc/hault/config AppName:vault-topic-manager VaultAddr:https://hault.105250-core-hault.svc.cluster.local:8200 VaultCACert:ca_pem HashiCorpVaultNamespace: Namespace:105250-core-vault SecretVersion:1 SecretPrefix:dev SecretKVBackend:secret AuthK8sBackend:kubernetes CSISecretMounts:{EnableCSIMount:false SecretMountPath:/etc/mount/ PathSeparator:!}}","time":"2024-05-08T12:45:41.191Z"} {"file":"infrastructure/aws_account_bootstrap/hault/teller/main.go:73","func":"main.main","kind":"application","level":"fatal","msg":"Error fetching authtoken: Error making API request.\n\nURL: PUT https://hault.105250-core-hault.svc.cluster.local:8200/v1/auth/kubernetes/login\nCode: 403. Errors:\n\n* permission denied","time":"2024-05-08T12:45:41.205Z"}




Created by Beniamin Kalinowski, last modified by Babak Habibnejad Gohardani on May 20, 2024
login to aws and select any environment (in this case dcore):

pcl aws -s



** for production environment these processes should be done from bastion host with breakglass access **



update kubeconfig to match the data:

aws eks update-kubeconfig --name dn-dcore --region eu-west-1



go into the pod running the cockroach db:

kubectl exec -it cockroach-client-0 -n 105250-cockroach-sql-client -- ./cockroach sql --certs-dir=cockroach-certs-copy --user=cockroach_client --url=postgresql://cockroach-public



restore a table:
RESTORE TABLE hault.vault_kv_store FROM LATEST IN 's3://105250-0000ie-dcore-cdb-backups-src/cockroach-backup?AUTH=implicit&AWS_REGION=eu-west-1' with kms = 'aws:///arn:aws:kms:eu-west-1:279924677952:alias/105250-0000ie-dcore-cockroach-cmk?AUTH=implicit&REGION=eu-west-1';



restore a database:
RESTORE TABLE hault FROM LATEST IN 's3://105250-0000ie-dcore-cdb-backups-src/cockroach-backup?AUTH=implicit&AWS_REGION=eu-west-1' with kms = 'aws:///arn:aws:kms:eu-west-1:279924677952:alias/105250-0000ie-dcore-cockroach-cmk?AUTH=implicit&REGION=eu-west-1';



in case of restoring existing database:
RESTORE DATABASE hault FROM LATEST IN 's3://105250-0000ie-dcore-cdb-backups-src/cockroach-backup?AUTH=implicit&AWS_REGION=eu-west-1' with new_db_name='hault_restore', kms = 'aws:///arn:aws:kms:eu-west-1:279924677952:alias/105250-0000ie-dcore-cockroach-cmk?AUTH=implicit&REGION=eu-west-1';



restore specific point in time DB:

SHOW BACKUPS in 's3://105250-0000ie-dcore-cdb-backups-src/cockroach-backup?AUTH=implicit&AWS_REGION=eu-west-1';

RESTORE DATABASE hault FROM '/2024/05/13-023000.00' IN 's3://105250-0000ie-dcore-cdb-backups-src/cockroach-backup?AUTH=implicit&AWS_REGION=eu-west-1' with new_db_name='hault_restore_test', kms = 'aws:///arn:aws:kms:eu-west-1:279924677952:alias/105250-0000ie-dcore-cockroach-cmk?AUTH=implicit&REGION=eu-west-1';





compare records from the two databases:

use hault;

select * from vault_kv_store where path='auth/346e90f8-c792-4081-de34-4a975aef2c75/role/vault-operator-role';

use hault_restore;
select * from vault_kv_store where path='auth/346e90f8-c792-4081-de34-4a975aef2c75/role/vault-operator-role';





to upload data from Cockroach to S3 bucket:

aws eks update-kubeconfig --name dn-dcore-data --region eu-west-1

no_proxy vaule needs to be changed when accessing the -data clusters:
export NO_PROXY='localhost,127.0.0.1,.jpmchase.net,.jpmorganchase.com'

kubectl -n 105250-cockroach-eu-west-1 exec -it cockroach-0 -- bash



ZIP_START_DATE=$(date -d '1 hour ago' "+%Y-%m-%d %H:%M:%S")

ZIP_START_DATE=$(date -d '1 hour ago' "+2024-05-07 05:00:00")

END_DATE=$(date "+2024-05-07 05:05:00")

FILE_NAME=$(date "+2024-05-07 05:05:00")





ZIP_START_DATE=$(date -d '1 hour ago' "+%Y-%m-%d %H:%M:%S")

ZIP_START_DATE=$(date -d '1 hour ago' "+2024-05-07 06:00:00")

END_DATE=$(date "+2024-05-07 06:05:00")

FILE_NAME=$(date "+2024-05-07 06:05:00")



cockroach debug zip debug-${FILE_NAME}.zip --certs-dir=../cockroach-certs-copy --files-from "${ZIP_START_DATE}" --files-until "${END_DATE}"

cockroach debug tsdump --certs-dir=../cockroach-certs-copy --format=raw --from "${TSDUMP_START_DATE}" --to "${END_DATE}" | gzip > tsdump-${FILE_NAME}.gob.gz



BUCKET_NAME="105250-0000ie-dcore-cdb-backups-src"

aws s3 cp tsdump-${FILE_NAME}.gob.gz s3://${BUCKET_NAME}/tsdump-${FILE_NAME}.gob.gz

aws s3 ls --human-readable s3://${BUCKET_NAME}/debug-${FILE_NAME}.zip

rm debug-${FILE_NAME}.zip


revert the no_proxy back to normal after the process

NO_PROXY='localhost,127.0.0.1,.jpmchase.net,.jpmorganchase.com,*.eks.amazonaws.com'



Connect to Cockroach
Created by Eric Zhang, last modified on Apr 24, 2024
pcl aws login -s



For example, select NCORE

aws eks update-kubeconfig --name dn-dcore --region eu-west-1

aws eks update-kubeconfig --name dn-icore --region eu-west-1

aws eks update-kubeconfig --name dn-ecore --region eu-west-1

aws eks update-kubeconfig --name dn-ncore --region eu-west-1




kubectl config set-context --current --namespace 105250-sentinel

kubectl exec -it cockroach-client-0 -n 105250-cockroach-sql-client -- ./cockroach sql --certs-dir=cockroach-certs-copy --user=cockroach_client --url=postgresql://cockroach-public





#! /usr/bin/env bash

function usage_list() {
  echo "Usage: $0 [-r failureReason]"
  echo " -r: Filtering reason [optional]"
  echo " -h: help"
  exit 1
}

while getopts r:f:h flag
do
  case "${flag}" in
    r) FAILURE_REASON_LIST_ARG=${OPTARG};;
    h) usage_list;; # Show the help
  esac
done

FAILURE_CONDITION=""

if [[ -n "${FAILURE_REASON_LIST_ARG}" ]]; then
  FAILURE_CONDITION="| select(.failure_reason | contains(\"${FAILURE_REASON_LIST_ARG}\"))"
fi

#SA TOKEN
TOKEN=$(aws secretsmanager get-secret-value --secret-id 105250-0000ie-${DYN_ENV}-sa-reposting-vault-tools-tennessee-token | jq -r '.SecretString' | jq -r ".token1")
PAGE_SIZE=50
URL="https://core-api.dn-${DYN_ENV}-vault.dynamo.${DYN_ENV_TYPE}.eu-west-1.aws.jpmchase.net/v1/post-posting-failures?page_size=${PAGE_SIZE}"

DATE=$(date -u +%Y%m%d_%H%M%S)
TMP_PAGE=$(mktemp /tmp/tmp.${DATE}-XXXXXXX --suffix=.json)
TMP_FAILURES=$(mktemp /tmp/tmp.failures.${DATE}-XXXXXXX --suffix=.json)
RESULT_FAILURES=$(mktemp /tmp/failures.${DATE}-XXXXXXX --suffix=.json)
PARAMS=

echo TMP_PAGE file: ${TMP_PAGE}
echo TMP_FAILURES file: ${TMP_FAILURES}
echo RESULT_FAILURES file: ${RESULT_FAILURES}
echo Pages processing start
while : ; do
    let i++
    echo Page: ${i} $NEXT_PAGE

    curl -s -k "$URL$PARAMS" -X GET -H "X-Auth-Token: $TOKEN" -H 'Content-Type: Application/Json' > ${TMP_PAGE}

    NEXT_PAGE=$(jq -r '.next_page_token' "${TMP_PAGE}")
    PARAMS="&page_token=$NEXT_PAGE"

    jq -r ".post_posting_failures" "${TMP_PAGE}" >> ${TMP_FAILURES}

    [[ -n "$NEXT_PAGE" ]] || break
done
echo Pages processing end with records count: $(jq -s 'add' ${TMP_FAILURES} | jq length)

echo "SUMMARY START ----------------------------------------------------------------------------------------------------"
jq -s 'add' ${TMP_FAILURES} | jq ". |= sort_by(.insertion_timestamp) | reverse" | jq ".[] ${FAILURE_CONDITION}" > ${RESULT_FAILURES}
export EXPORTED_RESULT_FAILURES=${RESULT_FAILURES}
cat ${EXPORTED_RESULT_FAILURES}
echo "SUMMARY END  -----------------------------------------------------------------------------------------------------"





#!/bin/bash

# Function to scale deployments
function scale_deployments() {
    local namespace=$1
    local scale_to=$2
    kubectl scale deployment --namespace=$namespace --replicas=$scale_to $(kubectl get deployments --namespace=$namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | egrep -v "vault-tools|istio-annotation-tm-webhook"  )
}

# Function to scale jobs
function scale_jobs() {
    local namespace=$1
    local scale_to=$2
    kubectl scale job --namespace=$namespace --replicas=$scale_to $(kubectl get job --namespace=$namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
}

# Function to scale statefulsets
function scale_statefulsets() {
    local namespace=$1
    local scale_to=$2
    kubectl scale statefulset --namespace=$namespace --replicas=$scale_to $(kubectl get statefulset --namespace=$namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
}

# Parse command-line arguments
while getopts ":n:s:" opt; do
    case $opt in
        n) namespace=$OPTARG ;;
        s) scale_to=$OPTARG ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

# Check if required arguments are provided
if [[ -z $namespace || -z $scale_to ]]; then
    echo "Usage: $0 -n <namespace> -s <scale>"
    exit 1
fi

# Scale deployments, jobs, and statefulsets
echo "Running autoscaler for $namespace - setting replicas to: $scale_to"
scale_deployments $namespace $scale_to




#!/bin/bash
# Help function
function usage() {
  echo "Usage: $0 -d deploymentName -n namespace -w wait "
  echo "  -d deploymentName: The name of the deployment/pod that we will restart [required]"
  echo "  -n namespace: The namespace [required]"

  echo "  -w: wait for pod to be restarted or not, before proceeding to the next  one  [optional]"
  exit 1
}
# Named  parameters
WAIT=false # Variable for the patch path
while getopts d:n:w flag
do
  case "${flag}" in
    d) DEPLOYMENT=${OPTARG};; # The resource type (pod, deployment, etc.)
    n) NAMESPACE=${OPTARG};; # The namespace
    w) WAIT=true;; # Indicate that you want to backup the original file
    h) usage;; # Show the help
  esac
done
# Check if all required parameters have been passed
if [ -z "$DEPLOYMENT" ] || [ -z "$NAMESPACE" ]; then
  echo "One or more required parameters are missing."
  usage
fi
if [ -z "$OPERATION" ]; then
  OPERATION=r
fi
echo "Starting POD restart for deployment $DEPLOYMENT";
cmList=$(kubectl get pods -n $NAMESPACE --no-headers=true -o custom-columns=NAME_OF_MY_POD:.metadata.name | grep -i $DEPLOYMENT )
for pod in "${cmList[@]}"
do
   #we prefer to delete the pods one by one to make sure that there is always one running
   if [ "$WAIT" = true ]; then
     kubectl delete pod $pod -n $NAMESPACE --wait;
     kubectl rollout status deployment $DEPLOYMENT -n $NAMESPACE --timeout=90s;
   else
     kubectl delete pod $pod -n $NAMESPACE;
   fi
done

echo "Finishing POD restart for deployment $DEPLOYMENT";



# !/bin/sh

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <namespace> <label>"
  exit 1
fi

LABEL="$1"
LABEL_KEY=$(echo $LABEL | cut -d ':' -f 1)
LABEL_VALUE=$(echo "$LABEL" | cut -d ':' -f 2 | sed 's/^ //')


label_resources() {
  # due to restriction for some of the statefulsets that are controlled by operator, we have to first patch the CRDs that control them
  RESOURCES=$(kubectl get prometheuses.monitoring.coreos.com -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
  for RESOURCE in $RESOURCES; do
    echo $LABEL_KEY
    # CRDs can't be patched via strategic-merge-patch+json, we have to patch them via merge-patch+json format
    kubectl patch prometheuses.monitoring.coreos.com $RESOURCE --type merge --patch '{"spec":{"podMetadata":{"labels":{"'$LABEL_KEY'":"'$LABEL_VALUE'"}}}}' -n $NAMESPACE
  done

  RESOURCE_TYPE=$1
  NAMESPACE=$2
  RESOURCES=$(kubectl get $RESOURCE_TYPE -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

  for RESOURCE in $RESOURCES; do
    echo "Adding label $LABEL_KEY to $RESOURCE_TYPE $RESOURCE"
    kubectl label $RESOURCE_TYPE $RESOURCE $LABEL_KEY=$LABEL_VALUE -n $NAMESPACE --overwrite
    if [ "$RESOURCE_TYPE" == "deployment" ] || [ "$RESOURCE_TYPE" == "statefulset" ] || [ "$RESOURCE_TYPE" == "daemonset" ]; then
      kubectl patch $RESOURCE_TYPE $RESOURCE --patch '{"spec":{"template":{"metadata":{"labels":{"'$LABEL_KEY'":"'$LABEL_VALUE'"}}}}}' -n $NAMESPACE
    else
      kubectl patch $RESOURCE_TYPE $RESOURCE --patch '{"spec":{"jobTemplate":{"spec":{"template":{"metadata":{"labels":{"'$LABEL_KEY'":"'$LABEL_VALUE'"}}}}}}}' -n $NAMESPACE
    fi
  done
}

# jobs are NOT added here as they are ephemeral resources and will finish after running, no need to add them for labeling to helm chart labeling scheme
RESOURCE_TYPES=("daemonset" "deployment" "statefulset" "cronjob")
NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

for NAMESPACE in $NAMESPACES; do
  for RESOURCE_TYPE in "${RESOURCE_TYPES[@]}"; do
    label_resources $RESOURCE_TYPE $NAMESPACE
  done
done
echo "Labeling finished"





#!/usr/bin/env bash
set -e
releaseJsonPath=$1
targetPath=$2

function buildAclsForResourceType() {

  kafka_requirement=$1
  resourceType=$2  # topic or group
  principal=$3
  baseACLCreationCommand="kafka-acls --bootstrap-server \$BOOTSTRAP_SERVER:9092 --command-config ~/connect.properties"

  if [[ $resourceType == "topic" ]]; then
    resources_configurations=$(echo $kafka_requirement | jq '.resources.topics' | jq -c '.[]');
  elif [[ $resourceType == "group" ]]; then
    resources_configurations=$(echo $kafka_requirement | jq '.resources.groups' | jq -c '.[]');
  fi;

  for resource_configuration in $resources_configurations; do
    echo -e "\nConstructing $resourceType related ACLs"

    permission_type=$(echo $resource_configuration | jq '.permission_type' | tr -d '"');
    permission_type_attribute=$(echo -e "--$permission_type-principal" | tr "[:upper:]" "[:lower:]")

    permissions_command=""
    permissions=$(echo $resource_configuration | jq '.permissions' | jq .[]);
    #echo "Discovered $resourceType permissions : $permissions";
    for permission in $permissions; do
      permission_updated=$(echo $permission | tr -d "\"")
      permissions_command+="--operation $permission_updated "
    done

    if [ $(echo $resource_configuration | jq 'has("prefixes")') == "true" ]
    then
      prefixes=$(echo $resource_configuration | jq '.prefixes' | jq .[]);
      echo "Commands to be executed:"
      for prefix in $prefixes; do
        prefix_updated=$(echo $prefix | tr -d "\"")
        echo -e "$baseACLCreationCommand --add --resource-pattern-type prefixed --allow-host '*' $permission_type_attribute User:$principal --$resourceType \"$prefix_updated\" $permissions_command" | tee -a $targetPath/acl_commands_full.txt
        echo -e "$baseACLCreationCommand --add --resource-pattern-type prefixed --allow-host '*' $permission_type_attribute User:vault-operator --$resourceType \"$prefix_updated\" $permissions_command" | tee -a $targetPath/acl_commands_vault_operator.txt
      done
    elif [ $(echo $resource_configuration | jq 'has("name")')  == "true" ]
    then
      topics=$(echo $resource_configuration | jq '.name' | jq .[]);
      echo "Commands to be executed:"
      for topic in $topics; do
        topic_updated=$(echo $topic | tr -d "\"")
        echo -e "$baseACLCreationCommand --add --resource-pattern-type literal --allow-host '*' $permission_type_attribute User:$principal --$resourceType \"$topic_updated\" $permissions_command" | tee -a $targetPath/acl_commands_full.txt
        echo -e "$baseACLCreationCommand --add --resource-pattern-type literal --allow-host '*' $permission_type_attribute User:vault-operator --$resourceType \"$topic_updated\" $permissions_command" | tee -a $targetPath/acl_commands_vault_operator.txt
      done
    fi

  done
}

kafka_requirements_list=$(cat $releaseJsonPath | jq '.metadata.kafka_principals | to_entries | .[] | select(.value.components[] | contains("observability") or contains("istio") or contains("vault-core") or contains("webhook-operator"))' | jq -c .value);
echo "Commands to be executed when creating full set of ACLs:" > $targetPath/acl_commands_full.txt
echo "" > $targetPath/acl_commands_vault_operator.txt
for kafka_requirement_json in $kafka_requirements_list; do

  principal=$(echo $kafka_requirement_json | jq '.principal' | tr -d "\"");
  echo "Discovered principal : $principal";

  component=$(echo $kafka_requirement_json | jq '.components');
  echo "Discovered components : $component";

  buildAclsForResourceType $kafka_requirement_json "topic" $principal
  buildAclsForResourceType $kafka_requirement_json "group" $principal

  echo -e "\n---------------------------------------------------------------------\n"

done

cat $targetPath/acl_commands_vault_operator.txt | sort -u | tee $targetPath/acl_commands_vault_operator_without_duplicates.txt




#!/usr/bin/env bash

set -e

environment_identifier=$1
vault_namespace=$2

echo "otel-collector config replacement starting"

export jpmcrootca_pem="$(cat /etc/pki/ca-trust/source/anchors/JPMCROOTCA.pem | sed 's/\r//g')"

echo "Fetching otel-collector secret"

otel_deployment=$(kubectl get deployment/otel-collector -n $vault_namespace -o json)
otel_deployment_configmap=$(jq -r '.spec.template.spec.volumes | map(select(.name | contains("otel-gateway-config-vol")))[0].configMap.name' <<< "${otel_deployment}" )

export gateway_yaml="
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_http:
        endpoint: 0.0.0.0:14268
processors:
  batch:
  memory_limiter:
    limit_mib: 1800
    spike_limit_mib: 512
    check_interval: 5s
extensions:
  health_check: {endpoint: "0.0.0.0:13133"}
exporters:
  otlphttp:
    endpoint: https://jaeger-collector.dynamo.$environment_identifier.eu-west-1.aws.jpmchase.net:444
    tls:
      insecure: false
      # cert_file: /conf/client.pem
      # key_file: /conf/client_key.pem
      ca_file: /conf/root_ca.pem
service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp, jaeger]
      processors: [memory_limiter, batch]
      exporters:
        - otlphttp
"

data='{ "data": {} }'
data=$(jq '.data += {"gateway.yaml": env.gateway_yaml}' <<< "${data}")
data=$(jq '.data += {"root_ca.pem": env.jpmcrootca_pem}' <<< "${data}")

echo "patching configmap $otel_deployment_configmap"
kubectl patch configmap/$otel_deployment_configmap -n $vault_namespace -p "$data"
kubectl rollout restart deployment/otel-collector -n $vault_namespace

echo "otel-collector config replacement completed"




#!/usr/bin/env bash
function usage() {
  echo "Usage: $0 [-s starttime] [-e endtime] [-l LOGGROUP]"
  echo "  -s starttime: Default: -1 week [optional]"
  echo "  -e endtime: Default: now [optional]"
  echo "  -l LOGGROUP: Default: ${LOGGROUP} [optional]"
  exit 1
}

DYN_ENV=$(echo "${AWS_ROLE_ARN}" | cut -d'-' -f3)
ACCOUNT=$(echo "${AWS_ROLE_ARN}" | cut -d':' -f5)

# Named  parameters
LOGGROUP="arn:aws:logs:eu-west-1:${ACCOUNT}:log-group:/aws/rds/cluster/db-105250-0000ie-${DYN_ENV}-tnn-core-vault-cluster/postgresql"
STARTTIME=$(date --date "-1 week" +%s)000
ENDTIME=$(date +%s)000

while getopts s:e:l: flag
do
  case "${flag}" in
    s) STARTTIME=${OPTARG};;
    e) ENDTIME=${OPTARG};;
    l) LOGGROUP=${OPTARG};;
    *) usage;;
  esac
done

function log_stream_names() {
    aws logs describe-log-streams --order-by LastEventTime --log-group-identifier "${LOGGROUP}" | \
      jq -r --argjson STARTTIME "${STARTTIME}" --argjson ENDTIME "${ENDTIME}" '.logStreams[] | select(.lastEventTimestamp > $STARTTIME) | select(.firstEventTimestamp < $ENDTIME) | .logStreamName'
}

function dump_logs() {
    log_stream_names | while read -r stream; do
      stream=$(echo "${stream}" |tr -d "[:space:]")

      num=0
      while true; do

        echo "${stream} ${num}"
        if [[ ${num} == 0 ]]; then
            ARGS=
        else
            ARGS=("--next-token" "${next_token}")
        fi
        aws logs get-log-events "${ARGS[@]}" \
            --start-from-head --start-time "${STARTTIME}" --end-time "${ENDTIME}" \
            --log-stream-name "${stream}" --log-group-identifier "${LOGGROUP}" > "${stream}.${num}"
        L=$(jq -r '.events|length' "${stream}.${num}")
        echo "${L}"
        next_token=$(jq -r '.nextForwardToken' "${stream}.${num}")
        echo "${next_token}"

        if [[ "${L}" == 0 ]]; then
            break
        fi

        num=$(( num + 1 ))
      done
    done
}

dump_logs




#!/bin/bash

while getopts ":b:c:" opt; do
    case $opt in
        b) basePath=$OPTARG ;;
        c) comparePath=$OPTARG ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

# Check if required arguments are provided
if [[ -z $basePath || -z $comparePath ]]; then
    echo "Usage: $0 -b <basePath> -c <comparePath>"
    exit 1
fi
# Scale deployments, jobs, and statefulsets
echo "Running Compare..."

files=$(find "$basePath" -type f )

for file in $files; do
  fileName=$(basename $file);
  compareFile=$(echo "$file" | sed "s#$basePath#$comparePath#g" );
  echo "Comparing $fileName against $compareFile \n"
  diff --color="always" -s $file  $compareFile;
done

echo "Compare completed!!!"






#!/bin/bash

set -e

# Help function
function usage() {
  echo "Usage: $0 [-n namespace] [-r listOfResourcesToBackup]  [-b]"
  echo "  -n namespace: The namespace you want to backup [optional] if not informed 105250-core-v"
  echo "  -r resources: The resources ou want to backup [optional] if not informed: jobs configmap services deployments statefulset horizontalpodautoscalers cronjob virtualservices ingresses crowns tmcomponents serviceaccounts"
  echo "  -b: Save the backup on S3 [optional]"
  echo "  -h: help"
  exit 1
}

BACKUP=true # Variable to indicate if you want to save the backup to S3
while getopts r:n:h::b flag
do
  case "${flag}" in
    r) RESOURCE=${OPTARG};; # The resource types
    n) NAMESPACE=${OPTARG};; # The namespace
    b) BACKUP=false;; # Indicate that you want to backup the original file
    h) usage;; # Show the help
  esac
done

if [ -z "$RESOURCE" ]; then
  RESOURCE="jobs configmap services deployments statefulset horizontalpodautoscalers cronjob virtualservices ingresses crowns tmcomponents serviceaccounts"
fi
if [ -z "$NAMESPACE" ]; then
  NAMESPACE="105250"
fi

CURRENTDATE=$(date '+%Y-%m-%d')

echo "Starting Backup process for $NAMESPACE with following resources in scope: $RESOURCE"
for NS in $(kubectl get ns| egrep -i $NAMESPACE | awk '{print $1}')
do
 for TYPE in $RESOURCE
   do
   echo "Grabbing $NS $TYPE"
     mkdir -p $CURRENTDATE/$NS/$TYPE
      for ENTITY in $(kubectl -n $NS get $TYPE| grep -v NAME| awk '{print $1}' )
      do
        kubectl -n $NS get $TYPE $ENTITY -o yaml > $CURRENTDATE/$NS/$TYPE/$ENTITY.yaml
      done
   done
done

COMMON="common"
echo ""
echo "START backup of COMMON Features in the Cluster : validatingwebhookconfigurations clusterrole clusterrolebinding namespaces mutatingwebhookconfiguration customresourcedefinitions priorityclasses"
for TYPE in validatingwebhookconfigurations clusterrole clusterrolebinding namespaces mutatingwebhookconfiguration customresourcedefinitions priorityclasses
do
echo "Grabbing $COMMON $TYPE"
	mkdir -p $CURRENTDATE/$COMMON/$TYPE
	for ENTITY in $(kubectl get $TYPE| grep -v NAME| awk '{print $1}')
	do
		kubectl get $TYPE $ENTITY -o yaml > $CURRENTDATE/$COMMON/$TYPE/$ENTITY.yaml
	done
done

echo "Completed Backup process..."

if [ -z "$BACKUP_S3_BUCKET" ]; then
  backupBucket="s3://$(aws s3 ls | grep -i vault-backup | awk '{print $3}' )"
else
  backupBucket=$BACKUP_S3_BUCKET
fi

if [ "$BACKUP" = true ];  then
  echo "Saving Backup on S3 bucket $backupBucket ..."
  aws s3 mv $CURRENTDATE "$backupBucket/$CURRENTDATE"  --recursive
  echo "Save completed"
fi






