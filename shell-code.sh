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



use sentinel_credit_monitoring_service;



