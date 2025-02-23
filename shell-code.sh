5. kubectl cp -n 105250-vault-operators crown-operator-XXXXX:/var/run/secrets/kubernetes.io/serviceaccount/..data/ca.crt  ./cert_vault-operator-sa : copy the certificate locally from crown operator
7. kubectl cp cert_vault-operator-sa -n 105250-core-hault hault-0:/tmp/cert_vault-operator-sa -c vault  : copy cert to hashicorp vault pod
10. kubectl cluster-info : find what ip address the kubernetes master is running at

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





"""
How to Use:
1. go to "105250-vault-operators" namespace and shell into "vault-tools-..." pod
2. go to /scripts folder
3. execute: python3 pgLsWaldirRoleGrant.py --db="db-105250-0000ie-dcore-tnn-core-vault-cluster"

this script will remove pg_monitor role (if it was added before), alter postgres user so that it can allow other
database users to execute pg_ls_waldir function.
"""

from blueGreenDeployment import DatabaseReplication, bcolors
import argparse
import logging


logging.basicConfig(level=logging.INFO)
EXCLUDE_DB = ["rdsadmin", "postgres", "tnn_core_vault", "nestlings_name"]
parser = argparse.ArgumentParser(description="database cluster name")
parser.add_argument("--db", type=str, required=True, help="Name of the DB")
args = vars(parser.parse_args())
db = args["db"]
FUNC = "pg_catalog.pg_ls_waldir"
db_conn = DatabaseReplication(blue_db=db, green_db=None, exclude_db=EXCLUDE_DB, replica_identity_full_data=None)
databases = db_conn.get_blue_databases()
db_conn.create_connection_pool()
logging.info(f"{db_conn}")
for database in databases:
    logging.info(f"{bcolors.OKBLUE}  Grant role {FUNC} for {database} {bcolors.ENDC}")
    try:
        # here we remove previously given role "pg_monitor" from the database users since it causes too much log
        # generation execution permission is given instead of the role, however we need to give permission of
        # ownership to postgres user, before it can grant execution to other users.
        db_conn.blue_connection_pool[database].execute(f"REVOKE pg_monitor FROM {database};")
        db_conn.blue_connection_pool[database].execute(f"ALTER FUNCTION {FUNC} OWNER TO postgres;")
        db_conn.blue_connection_pool[database].execute(f"GRANT EXECUTE ON FUNCTION {FUNC} TO {database};")
    except Exception as e:
        logging.info(f"Failed grant {FUNC} execution for {database}, {e}")
        raise Exception("Cannot grant execute {FUNC} to user {database}")






 """
Documentation about script usage:
https://confluence.dynamo.prd.aws.jpmchase.net/display/DIGPROJECT/Vault+Blue-Green+DB+update
"""

import boto3
import json
import psycopg2
import logging
import re
import copy
import subprocess
from time import sleep, time
import datetime
import argparse
import dns.resolver
from botocore.exceptions import NoCredentialsError, ClientError
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT, AsIs
from psycopg2.errors import DuplicateObject, OperationalError
from collections import defaultdict

# Region, used for retrival DB secrets from AWS
REGION = "eu-west-1"
# Path where store pg_dump date
PG_BACKUP_PATH = "/tmp/"
# List of databases, excluded from replication
EXCLUDE_DB = ["rdsadmin", "postgres"]
# Data provided by TM: THUNDERBAL-176
# List of tables where REPLICA IDENTITY FULL must be set, structure: db: [schema_name.table_name]
# Structure = DB:[Tables]
REPLICA_IDENTITY_FULL = {
    "vault": [
        "directives_committer.buffer",
        "accounts.control_table",
        "accounts.payment_device_link_updates",
        "accounts.payment_device_updates",
        "ledger_balances.balance_values",
        "payment_submission.submissions",
        "plans.plan_schedule_assoc_batches",
        "plans.plan_schedule_assoc_statuses",
        "posting_api.postings",
        "public.account_details",
        "public.account_stakeholders",
        "public.additional_user_details",
        "public.contract_code_execution",
        "public.contract_parameter_values",
        "public.contract_parties",
        "public.contract_signatures",
        "public.contract_tags",
        "public.contract_template_features",
        "public.contract_template_tags",
        "public.migrations",
        "public.restriction_definitions",
        "public.user_details",
    ],
    "ledger_balances": ["ledger_balances.global_watermarks"],
    "data_retention": ["public.migrations"],
    "access_control": ["public.migrations"],
    "calendar": ["public.migrations"],
    "calendar_schedules": ["public.migrations"],
    "data_loader": ["public.migrations"],
    "eplatform": ["public.migrations", "public.workflow_parent_child_assoc"],
    "ops": ["public.migrations"],
    "schedule_manager": ["public.migrations"],
    "switchboard": ["public.migrations"],
    "xpl": ["public.migrations"],
    "scheduler": [
        "public.migrations",
        "scheduler.schedule_group_membership",
        "scheduler.schedules_tags",
        "scheduler.update_group_requests",
        "scheduler.update_tag_requests",
    ],
    "integrations": [
        "public.migrations",
        "credit_transfer_scheduler.scheduled_credit_transfers",
    ],
}
REPLICA_IDENTITY_ON_INDEX = {
    "vault": {
        "posting_api.client_transaction_instruction_count": "unique_client_id_and_client_tnx_id"
    }
}
# Owner user of databases under migration
DB_OWNER = "vault_admin"
# Service responsible for DB connection and namespaces
DB_POOL = {"105250-core-vault": "dbpool"}
# Dict of tables for which separate replication slots should be created
# format {db:[schema_name.table_name]}
DB_TABLES_SEPARATE_REPLICATION = {
    "vault": [
        "posting_api.posting_instructions",
        "posting_api.account_postings",
        "posting_api.posting_instruction_batches",
        "balance.balance_values",
        "posting_api.postings",
        "posting_api.client_transaction_instruction_count",
        "balance.account_balance_journal",
    ],
    "ledger_balances": [
        "ledger_balances.balance_values",
        "ledger_balances.bucket_entries",
        "ledger_balances.processed_bucket_entries",
    ],
}
# Optional sleep after creation/removing of resources
OPTIONAL_SlEEP = True
# Amount of an attempt to check lag during switch to green db
LAG_CHECK_TIMES = 3
# Route53 record for Vault DB
ROUTE_53_RECORD = "blue-green.vault-aurora.dynamo.prod.eu-west-1.aws.jpmchase.net"


class bcolors:
    OKBLUE = "\033[94m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"


def get_rds_connection_string(rds_db_name):
    try:
        rds_client = boto3.client("rds", region_name=REGION)
        secrets_manager_client = boto3.client("secretsmanager", region_name=REGION)
        response = rds_client.describe_db_clusters(DBClusterIdentifier=rds_db_name)
        db_cluster = response["DBClusters"][0]
        endpoint = db_cluster["Endpoint"]
        if not db_cluster:
            raise ValueError("No DB Clusters found")
        secret_id = db_cluster["MasterUserSecret"]["SecretArn"]
        secret_value = secrets_manager_client.get_secret_value(SecretId=secret_id)
        credentials = json.loads(secret_value["SecretString"])
        user = credentials["username"]
        password = credentials["password"]
        logging.info(
            f"{bcolors.OKGREEN}Connection string for {endpoint} for acquired{bcolors.ENDC}"
        )
        return {"user": user, "host": endpoint, "password": password}
    except ClientError as e:
        return {"error": str(e)}


def optional_sleep(duration):
    if OPTIONAL_SlEEP:
        sleep(duration)


def kubernetes_scaler(replicas):
    logging.info(f"Scaling {DB_POOL} --replicas {replicas}")
    try:
        subprocess.run(
            [
                "kubectl",
                "scale",
                "-n",
                list(DB_POOL.keys())[0],
                "deployment",
                list(DB_POOL.values())[0],
                "--replicas",
                str(replicas),
            ],
            check=True,
            text=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as e:
        logging.error(f"Filed to scale {DB_POOL}, {e}")


class DBConnection(psycopg2.extensions.connection):
    def __init__(self, connection_data, db, user="postgres"):
        self.connection = psycopg2.connect(
            dbname=db,
            user=user,
            host=connection_data["host"],
            password=connection_data["password"],
            sslmode="require",
        )
        self.connection.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        self.cur = self.connection.cursor()

    def execute(self, query):
        try:
            self.cur.execute(query)
            return True
        except DuplicateObject as e:
            logging.warning(f"{bcolors.WARNING}Resource already exist {e}")
            return False
        except Exception as e:
            logging.critical(f"{bcolors.FAIL}Unhandled exception {e}")
            self.close_connection()
            raise

    def fetchall(self):
        return self.cur.fetchall()

    def close_connection(self):
        logging.info(f"{bcolors.OKGREEN} Closing connection to ")
        self.cur.close()
        self.connection.close()


class DatabaseReplication:
    def __init__(
        self,
        blue_db,
        green_db,
        exclude_db,
        replica_identity_full_data,
        replica_identity_on_index=None,
    ):
        self.blue_db = blue_db
        self.green_db = green_db
        self.blue_connection = get_rds_connection_string(blue_db)
        self.green_connection = None
        self.excluded_db = exclude_db
        self.blue_databases = []
        self.green_connection_pool = {}
        self.blue_connection_pool = {}
        self.blue_user = self.blue_connection["user"]
        self.green_user = None
        self.replica_identity_full_data = replica_identity_full_data
        self.replica_identity_on_index = replica_identity_on_index
        self.replication_slots = defaultdict(dict)
        self.slots_list = []
        if self.green_db:
            self.green_connection = get_rds_connection_string(self.green_db)
            self.green_user = self.green_connection["user"]

    def get_blue_databases(self):
        blue_db_postgres = DBConnection(self.blue_connection, db="postgres")
        blue_db_postgres.execute(
            "SELECT datname FROM pg_database WHERE datistemplate = false;"
        )
        databases = [
            db[0] for db in blue_db_postgres.fetchall() if db[0] not in self.excluded_db
        ]
        blue_db_postgres.close_connection()
        logging.info(f"{bcolors.OKGREEN}Retrieved list of databases {databases}")
        blue_db_postgres.close_connection()
        if databases:
            self.blue_databases = databases
            return self.blue_databases
        else:
            logging.fatal(f"{bcolors.FAIL}Retrieved empty list of database")
            raise ValueError

    def create_connection_pool(self):
        for database in self.blue_databases:
            logging.info(f"{bcolors.OKGREEN}Create connection for Blue DB {database}")
            self.blue_connection_pool[database] = DBConnection(
                self.blue_connection, db=database
            )
            if self.green_db:
                self.green_connection_pool[database] = DBConnection(
                    self.green_connection, db=database
                )

    def permission_for_user(self, database, command="REVOKE"):
        logging.info(
            f"{bcolors.OKGREEN}{command} all permissions to blue {self.blue_user} "
            f"and green {self.green_user} on {database}"
        )
        direction = "FROM"
        if command == "GRANT":
            direction = "TO"
        self.blue_connection_pool[database].execute(
            f"{command} ALL PRIVILEGES ON DATABASE {database} {direction} {self.blue_user};"
        )
        self.green_connection_pool[database].execute(
            f"{command} ALL PRIVILEGES ON DATABASE {database} {direction} {self.green_user};"
        )

    def publications_ops(self, database, is_create_slot=False, is_drop_slot=False):
        self.fetch_publications(database)
        logging.info(f"{bcolors.OKGREEN} Processing DB {database}")
        for k, v in self.replication_slots[database].items():
            if is_drop_slot:
                logging.info(
                    f"Dropping replication slots {k} for tables {v} for database {database}"
                )
                self.green_connection_pool[database].execute(
                    "SELECT aurora_volume_logical_start_lsn();"
                )
                start_lsn = self.green_connection_pool[database].fetchall()
                logging.warning(
                    f"{bcolors.WARNING} Value of start_lsn. Important, note it for future update {start_lsn}"
                )
                try:
                    self.green_connection_pool[database].execute(
                        f"SELECT pg_drop_replication_slot('{k}'); "
                    )
                except Exception as e:
                    logging.debug(f"Slot non existing or cannot be removed {e}")
            else:
                if database in DB_TABLES_SEPARATE_REPLICATION:
                    if v != "all":
                        logging.info(
                            f"Creating replication {k} for tables {v} for database {database}"
                        )
                        self.blue_connection_pool[database].execute(
                            f"CREATE PUBLICATION {k} FOR TABLE {v} ;"
                        )
                    else:
                        raise ValueError(
                            "Attempt to create PUBLICATION "
                            "for table, expected for ALL TABLES"
                        )
                else:
                    logging.info(
                        f"Creating replication for ALL TABLES for database {database}"
                    )
                    self.blue_connection_pool[database].execute(
                        f"CREATE PUBLICATION {database} FOR ALL TABLES;",
                    )
                if is_create_slot:
                    logging.info(
                        f"Creating replication slots {k} for tables {v} for database {database}"
                    )
                    self.blue_connection_pool[database].execute(
                        f"SELECT pg_create_logical_replication_slot('{k}', 'pgoutput');"
                    )

    def fetch_publications(self, database):
        logging.info(f"Fetching publications for DB {database}")
        self.blue_connection_pool[database].execute(
            "SELECT table_schema || '.' || table_name AS schema_table "
            "FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') "
            "AND table_type='BASE TABLE' ORDER BY table_schema, table_name;"
        )
        all_tables = self.blue_connection_pool[database].fetchall()
        if database in DB_TABLES_SEPARATE_REPLICATION:
            all_tables_list = [item[0] for item in all_tables]
            # Method produce replication_slots dict, that contain databases
            # which will be replicating ALL TABLES, tables that have own
            # replication slots and left_tables_list, tables that need to∂ be
            # replicated in current db but do not require separate slot
            left_tables_list = copy.deepcopy(all_tables_list)
            tables_for_separate_slots = DB_TABLES_SEPARATE_REPLICATION[database]
            for table in all_tables_list:
                if table in tables_for_separate_slots:
                    publication_name = database + "_" + table.replace(".", "_")
                    self.replication_slots[database][publication_name] = table
                    left_tables_list.remove(table)
            left_tables = ",".join(left_tables_list)
            self.replication_slots[database][database] = left_tables
        else:
            self.replication_slots[database][database] = "all"
        return self.replication_slots

    def create_subscriptions_for_green_db(self, database):
        for slot in self.replication_slots[database].keys():
            logging.info(
                f"{bcolors.OKGREEN}Create subscription for Green DB {database} publisher {slot}{bcolors.ENDC}"
            )
            self.green_connection_pool[database].execute(
                f"CREATE SUBSCRIPTION {slot} "
                f"CONNECTION 'host={self.blue_connection['host']}"
                f" port=5432 dbname={database} sslmode=require user={self.blue_connection['user']}"
                f" password={self.blue_connection['password']}' "
                f"PUBLICATION {slot} WITH (copy_data = false, create_slot = false, enabled = false, synchronous_commit=remote_apply, "
                f"connect = true, slot_name ={slot});"
            )

    def set_pg_replication_origin_advance(self):
        slots_con = DBConnection(self.green_connection, db="postgres")
        slots_con.execute("SELECT * FROM pg_replication_origin;")
        pg_replication_origins = slots_con.fetchall()
        logging.warning(
            f"{bcolors.WARNING} Value of pg_replication_origin. {pg_replication_origins}"
        )
        slots_con.execute("SELECT aurora_volume_logical_start_lsn();")
        last_lsn = input(
            "Please provide value of last_lsn, it was provided by script on step drop_publishers_green: "
        )
        if input(f"Please type yes to confirm last_lsn {last_lsn}: ").lower() == "yes":
            logging.warning(
                f"{bcolors.WARNING} Value of lat lsn for sync job: {last_lsn}"
            )
            for origin in pg_replication_origins:
                origin = origin[1]
                logging.info(f"Process origin {origin} and set lsn {last_lsn}")
                slots_con.execute(
                    f"SELECT pg_replication_origin_advance('{origin}', '{last_lsn}');"
                )
        else:
            logging.critical("Last LSN is not confirmed, exit")
            exit(1)

    def enable_replication_slot(self, database, slot_creation_delay):
        for slot in self.replication_slots[database].keys():
            logging.info(f"Enabling replication slot {slot}")
            self.green_connection_pool[database].execute(
                f"ALTER SUBSCRIPTION {slot} ENABLE;"
            )
            logging.debug(f"Waiting {slot_creation_delay} before enabling next slot")
            optional_sleep(slot_creation_delay)

    def alter_subscriptions_for_green_db(self, database):
        logging.info(
            f"{bcolors.OKGREEN}Alter subscription for Green DB {database}{bcolors.ENDC}"
        )
        for slot in self.replication_slots[database].keys():
            self.green_connection_pool[database].execute(
                f"ALTER SUBSCRIPTION {slot} "
                f"CONNECTION 'host={self.blue_connection['host']}"
                f" port=5432 dbname={database} sslmode=require user={self.blue_connection['user']}"
                f" password={self.blue_connection['password']}' "
            )

    def delete_replication_slots(self, database, publication):
        logging.info(
            f"{bcolors.OKGREEN} Deleting replication slot {database} {bcolors.ENDC}"
        )
        try:
            self.blue_connection_pool[database].execute(
                f"select pg_drop_replication_slot('{publication}');"
            )
        except Exception as e:
            if "is active for PID" in e:
                pid = re.search(r"PID (\d+)", e).group(1)
                logging.warning(
                    f"{bcolors.OKBLUE}Force remove of slot {publication}{bcolors.ENDC}"
                )
                self.green_connection_pool[database].execute(
                    f"SELECT pg_terminate_backend({pid});"
                    f" select pg_drop_replication_slot('{publication}');"
                )
            else:
                logging.critical(
                    f"{bcolors.FAIL}Unhandled exception occurred {bcolors.ENDC}"
                )
                exit()

    def delete_publication(self, database, publication):
        logging.info(
            f"{bcolors.OKBLUE}Deleting publication {publication} for DB {database}{bcolors.ENDC}"
        )
        self.blue_connection_pool[database].execute(
            f"DROP PUBLICATION IF EXISTS {publication} "
        )

    def delete_subscriptions(self, database, subscription):
        logging.info(
            f"{bcolors.OKGREEN}Deleting subscription {subscription} for DB {database}{bcolors.ENDC}"
        )
        self.green_connection_pool[database].execute(
            f"ALTER SUBSCRIPTION {subscription} DISABLE;  "
            f"ALTER SUBSCRIPTION {subscription} SET (slot_name=NONE); "
        )
        self.green_connection_pool[database].execute(
            f"DROP SUBSCRIPTION IF EXISTS {subscription};"
        )

    def get_slots(self):
        slots_con = DBConnection(self.blue_connection, db="postgres")
        slots_con.execute("SELECT slot_name FROM pg_replication_slots;")
        self.slots_list = [item[0] for item in slots_con.fetchall()]
        return self.slots_list

    def check_lag(self, databases, mode="Simple"):
        database_rows_compare = {}
        query = (
            "WITH RECURSIVE pg_inherit(inhrelid, inhparent) AS (select inhrelid, inhparent FROM pg_inherits UNION "
            "SELECT child.inhrelid, parent.inhparent FROM pg_inherit child, pg_inherits parent WHERE "
            "child.inhparent = parent.inhrelid), pg_inherit_short AS (SELECT * FROM pg_inherit WHERE inhparent "
            "NOT IN (SELECT inhrelid FROM pg_inherit)) SELECT table_schema , TABLE_NAME , row_estimate , "
            "pg_size_pretty(total_bytes) AS total , pg_size_pretty(index_bytes) AS INDEX , pg_size_pretty("
            "toast_bytes) AS toast , pg_size_pretty(table_bytes) AS TABLE , total_bytes::float8 / sum("
            "total_bytes) OVER () AS total_size_share FROM ( SELECT *, total_bytes-index_bytes-COALESCE("
            "toast_bytes,0) AS table_bytes FROM ( SELECT c.oid , nspname AS table_schema , relname AS TABLE_NAME "
            ", SUM(c.reltuples) OVER (partition BY parent) AS row_estimate , SUM(pg_total_relation_size(c.oid)) "
            "OVER (partition BY parent) AS total_bytes , SUM(pg_indexes_size(c.oid)) OVER (partition BY parent) "
            "AS index_bytes , SUM(pg_total_relation_size(reltoastrelid)) OVER (partition BY parent) AS "
            "toast_bytes , parent FROM ( SELECT pg_class.oid , reltuples , relname , relnamespace , "
            "pg_class.reltoastrelid , COALESCE(inhparent, pg_class.oid) parent FROM pg_class LEFT JOIN "
            "pg_inherit_short ON inhrelid = oid WHERE relkind IN ('r', 'p') AND pg_class.relname NOT LIKE 'pg_%' ) c "
            "LEFT JOIN pg_namespace n ON "
            "n.oid = c.relnamespace ) a WHERE oid = parent AND total_bytes - index_bytes - "
            "COALESCE(toast_bytes, 0) > 0 AND table_schema NOT IN ('pg_catalog', 'information_schema') ) a ORDER BY total_bytes DESC;"
        )
        postgres = DBConnection(self.blue_connection, db="postgres")
        while True:
            all_clear = True
            postgres.execute(
                "select application_name, state, pg_wal_lsn_diff(sent_lsn, write_lsn) "
                "as write_lag, pg_wal_lsn_diff(sent_lsn, flush_lsn) as flush_lag,  "
                "pg_wal_lsn_diff(sent_lsn, replay_lsn) as replay_lag from pg_stat_replication;"
            )
            lag_data = postgres.fetchall()
            logging.info(f"{bcolors.OKBLUE} Lag data {lag_data} {bcolors.ENDC} \n")
            for row in lag_data:
                state, write_lag, flush_lag, replay_lag = row[1], row[2], row[3], row[4]
                if not (
                    write_lag == 0
                    and flush_lag == 0
                    and replay_lag == 0
                    and state == "streaming"
                ):
                    all_clear = False
            if mode == "Full":
                for database in databases:
                    self.green_connection_pool[database].execute(query)
                    self.blue_connection_pool[database].execute(query)
                    db_data_green = self.green_connection_pool[database].fetchall()
                    db_data_blue = self.blue_connection_pool[database].fetchall()
                    database_rows_compare[database] = db_data_green == db_data_blue
                    for row_blue, row_green in zip(db_data_blue, db_data_green):
                        if row_green != row_blue:
                            logging.error(
                                f"{bcolors.WARNING}For database {database} schema {row_blue[1]} "
                                f"different data entries, please compare {row_green} and {row_blue}"
                                f"{bcolors.ENDC}"
                            )
                            database_rows_compare[database] = [
                                False,
                                row_blue,
                                row_green,
                            ]
                        else:
                            logging.info(
                                f"{bcolors.OKGREEN}Database {database} schema {row_blue[1]}"
                                f" is similar for Blue and "
                                f"Green{bcolors.ENDC}"
                            )
                            database_rows_compare[database] = [
                                True,
                                row_blue,
                                row_green,
                            ]
                current_time = datetime.datetime.now(datetime.timezone.utc).strftime(
                    "%Y-%m-%d_%H-%M-%S"
                )
                filename = f"/tmp/blue_green_compare_{current_time}.txt"
                with open(filename, "w") as file:
                    json.dump(database_rows_compare, file)
                logging.info(f"Datafile {filename} created")
                if not all(value[0] for value in database_rows_compare.values()):
                    all_clear = False
                logging.debug("DB comparing cycle finished")
                sleep(30)
            if all_clear:
                logging.info(
                    f"{bcolors.OKGREEN} Lag is 0 for all databases and state streaming, same amount of rows"
                    f" ready for switch to green DB {bcolors.ENDC}"
                )
                break
            optional_sleep(1)

    def recreate_pg_stat_statements(self, database):
        logging.info(
            f"{bcolors.OKBLUE} Recreating pg_stat_statements for {database}{bcolors.ENDC}"
        )
        for pool in [self.green_connection_pool, self.blue_connection_pool]:
            pool[database].execute("DROP EXTENSION IF EXISTS pg_stat_statements;")
            pool[database].execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements;")

    def grant_role(self, user, role):
        logging.info(f"{bcolors.OKBLUE}  Grant role {role} for {user} {bcolors.ENDC}")
        for pool in [self.green_connection_pool, self.blue_connection_pool]:
            try:
                pool[user].execute(f"GRANT {role} to {user};")
            except Exception as e:
                logging.info(f"Failed grant {role} for {user}, {e}")

    def close_connection_pools(self):
        logging.info(
            f"{bcolors.OKGREEN}Closing green and blue connection pools{bcolors.ENDC}"
        )
        for database in self.blue_databases:
            self.blue_connection_pool[database].close_connection()
            if self.green_db:
                self.green_connection_pool[database].close_connection()

    def replica_identity_full(self, database):
        tables = self.replica_identity_full_data.get(database)
        if tables:
            replica_identity_set = []
            for table in tables:
                logging.info(
                    f"{bcolors.OKGREEN} ALTER TABLE {table} REPLICA IDENTITY FULL for "
                    f"{database}{bcolors.ENDC}"
                )
                self.blue_connection_pool[database].execute(
                    f"ALTER TABLE {table} REPLICA IDENTITY FULL;"
                )
                replica_identity_set.append(table)
            if replica_identity_set == REPLICA_IDENTITY_FULL[database]:
                logging.info(
                    f"All tables from REPLICA_IDENTITY_FULL set for {database}"
                )
            else:
                logging.critical("Not all REPLICA_IDENTITY_FULL set")
                raise ValueError
        index_settings = self.replica_identity_on_index.get(database)
        if index_settings:
            for table, index in index_settings.items():
                logging.info(
                    f"{bcolors.OKGREEN} ALTER TABLE {table} REPLICA IDENTITY USING INDEX {index} for "
                    f"{database}{bcolors.ENDC}"
                )
                self.blue_connection_pool[database].execute(
                    f"ALTER TABLE {table} REPLICA IDENTITY USING INDEX {index};"
                )

    def alter_password(self, user):
        try:
            logging.info(f"Changing password for {user}")
            green_db = DBConnection(self.green_connection, db="postgres")
            password = self.green_connection["password"]
            green_db.execute(f"ALTER USER {user} WITH PASSWORD '{password}';")
        except Exception as e:
            logging.warning(f"Exception during Green DB password change {e}")

    def update_sequences(self, database):
        logging.info(
            f"{bcolors.WARNING}Update sequences of all tables for Green {database}{bcolors.ENDC}"
        )
        self.green_connection_pool[database].execute(
            "DO $$ DECLARE r record; BEGIN FOR r IN SELECT sequence_schema, sequence_name, table_name, column_name "
            "FROM information_schema.sequences JOIN information_schema.columns ON column_default LIKE 'nextval(%' || "
            "sequence_name || '%::regclass)' LOOP EXECUTE format('SELECT setval(''%I.%I'', (SELECT COALESCE(MAX("
            "%I)::bigint, 1) FROM %I.%I))', r.sequence_schema, r.sequence_name, r.column_name, r.sequence_schema, "
            "r.table_name); END LOOP; END $$;"
        )

    def check_dns(self):
        try:
            answers = str(dns.resolver.resolve(ROUTE_53_RECORD, "CNAME")[0]).rstrip(".")
            logging.info(f"Resolved domain {answers}")
            sleep(10)
            if answers in [self.green_connection["host"], self.blue_connection["host"]]:
                return 1
            return 0
        except Exception as e:
            logging.critical(f"Cannot fetch route53 domain, {e}")
            exit(1)


def create_replication(data_base_replicator, databases, slot_creation_delay):
    existing_slots = data_base_replicator.get_slots()
    logging.info(f"Already existing slots {existing_slots}")
    data_base_replicator.alter_password(DB_OWNER)
    for database in databases:
        if not any(slot.startswith(database) for slot in existing_slots):
            data_base_replicator.recreate_database(database=database, user=DB_OWNER)
    data_base_replicator.create_connection_pool()
    for database in databases:
        if database not in existing_slots:
            try:
                data_base_replicator.fetch_publications(database)
                data_base_replicator.permission_for_user(database, command="GRANT")
                if not any(slot.startswith(database) for slot in existing_slots):
                    data_base_replicator.pg_dump_restore(
                        database=database, command="dump"
                    )
                    data_base_replicator.pg_dump_restore(
                        database=database, command="restore", user=DB_OWNER
                    )
                data_base_replicator.publications_ops(database)
                data_base_replicator.create_subscriptions_for_green_db(database)
                data_base_replicator.recreate_pg_stat_statements(database)
                data_base_replicator.replica_identity_full(database)
            except Exception as e:
                logging.critical(
                    f"{bcolors.FAIL}Unhandled expedition occurred during creating replication "
                    f"for {database} {e}{bcolors.ENDC}"
                )
        else:
            logging.info(
                f"Replication slot for database {database} already exist. Skipping."
            )


def create_publishers(data_base_replicator, databases):
    existing_slots = data_base_replicator.get_slots()
    logging.info(f"Already existing slots {existing_slots}")
    data_base_replicator.alter_password(DB_OWNER)
    data_base_replicator.create_connection_pool()
    for database in databases:
        if database not in existing_slots:
            try:
                data_base_replicator.publications_ops(database, is_create_slot=True)
                data_base_replicator.replica_identity_full(database)
            except Exception as e:
                logging.critical(
                    f"{bcolors.FAIL}Unhandled expedition occurred during creating replication "
                    f"for {database} {e}{bcolors.ENDC}"
                )
        else:
            logging.info(
                f"Replication slot for database {database} already exist. Skipping."
            )


def delete_publishers(data_base_replicator, databases):
    data_base_replicator.create_connection_pool()
    for database in databases:
        data_base_replicator.publications_ops(database, is_drop_slot=True)


def create_subscriptions(
    data_base_replicator,
    databases,
    slot_creation_delay,
    force_create=False,
    configure_db=False,
):
    existing_slots = data_base_replicator.get_slots()
    logging.info(f"Already existing slots {existing_slots}")
    data_base_replicator.alter_password(DB_OWNER)
    data_base_replicator.create_connection_pool()
    for database in databases:
        if database not in existing_slots or force_create:
            try:
                data_base_replicator.fetch_publications(database)
                data_base_replicator.permission_for_user(database, command="GRANT")
                data_base_replicator.create_subscriptions_for_green_db(database)
                if configure_db:
                    data_base_replicator.recreate_pg_stat_statements(database)
                    data_base_replicator.replica_identity_full(database)
            except Exception as e:
                logging.critical(
                    f"{bcolors.FAIL}Unhandled expedition occurred during creating replication "
                    f"for {database} {e}{bcolors.ENDC}"
                )
        else:
            logging.info(
                f"Replication slot for database {database} already exist. Skipping."
            )
    data_base_replicator.set_pg_replication_origin_advance()
    if input("Type yes, to enable all slots: ").lower() == "yes":
        for database in databases:
            data_base_replicator.enable_replication_slot(database, slot_creation_delay)


def clean_up_replication(data_base_replicator, database):
    try:
        publications = data_base_replicator.fetch_publications(database)
        for publication in publications[database].keys():
            data_base_replicator.delete_subscriptions(database, publication)
            data_base_replicator.delete_replication_slots(database, publication)
            data_base_replicator.delete_publication(database, publication)
        data_base_replicator.permission_for_user(database, command="REVOKE")
    except Exception as e:
        logging.critical(
            f"{bcolors.FAIL}Unhandled expedition occurred during cleanup of {database} {e}{bcolors.ENDC}"
        )


def restart_ns(namespaces):
    try:
        logging.info(f"Attempt to kill all pods {DB_POOL.keys()} namespaces")
        subprocess.run(
            [
                "kubectl",
                "delete",
                "pods",
                "--all",
                "--force",
                "--grace-period=0",
                "-n",
                list(namespaces)[0],
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        logging.info(f"Rollout completed for namespace: {list(namespaces)[0]}")
    except Exception as e:
        logging.warning(
            f"Failed to restart {DB_POOL.keys()} namespace {e}, consider manual NS restart"
        )


def main():
    parser = argparse.ArgumentParser(description="Custom blue/green replicator")
    parser.add_argument(
        "--blue-db", type=str, required=True, help="Name of the Blue DB"
    )
    parser.add_argument(
        "--green-db", type=str, required=False, help="Name of the Green DB"
    )
    parser.add_argument(
        "--mode",
        type=str,
        required=True,
        help="Script mode",
        choices=[
            "create_replication",
            "delete_replication",
            "check_lag",
            "recreate_pg_stat_statements",
            "grant_pg_monitor",
            "green_switchover",
            "update_sequences",
            "subscriptions_password_update",
            "create_publishers_blue",
            "drop_publishers_green",
            "create_subscribers_green",
        ],
    )
    parser.add_argument(
        "--db-only",
        type=str,
        required=False,
        help="Sceptic postgres database where replication should be add/removed",
    )
    parser.add_argument(
        "--slot-creation-delay",
        type=int,
        required=False,
        default=20,
        help="Waiting time before next replication creation, s",
    )
    parser.add_argument(
        "--automated-mode",
        type=bool,
        required=False,
        default=False,
        help="Automated mod do not ask for confirmation",
    )
    args = vars(parser.parse_args())
    blue_db = args["blue_db"]
    green_db = args["green_db"]
    logging.info(
        f"{bcolors.OKBLUE}Starting replication blueDB {blue_db}, greenDB {green_db}{bcolors.ENDC}"
    )
    data_base_replicator = DatabaseReplication(
        blue_db=blue_db,
        green_db=green_db,
        exclude_db=EXCLUDE_DB,
        replica_identity_full_data=REPLICA_IDENTITY_FULL,
        replica_identity_on_index=REPLICA_IDENTITY_ON_INDEX,
    )
    if args["db_only"]:
        blue_databases = [args["db_only"]]
        data_base_replicator.blue_databases = blue_databases
    else:
        blue_databases = data_base_replicator.get_blue_databases()
    if args["mode"] == "create_replication":
        if args["automated_mode"] or (
            input(
                f"{bcolors.WARNING}IMPORTANT! Action will TRUNCATE all tables in {green_db}, "
                f"and configured replication from {blue_db} to {green_db}. "
                f"Please double check and "
                f"type yes to confirm: {bcolors.ENDC}"
            ).lower()
            == "yes"
        ):
            create_replication(
                data_base_replicator=data_base_replicator,
                databases=blue_databases,
                slot_creation_delay=args["slot_creation_delay"],
            )
    elif args["mode"] == "delete_replication":
        data_base_replicator.create_connection_pool()
        data_base_replicator.check_lag(blue_databases)
        if (
            input(
                f"{bcolors.WARNING}IMPORTANT! Action will remove ALL publishers, replication slot from "
                f"{blue_db}, subscriptions from {green_db}, and revoke permissions from "
                f"postgres user from {blue_databases} "
                f"type yes to confirm:  {bcolors.ENDC}"
            ).lower()
            == "yes"
        ):
            for database in blue_databases:
                clean_up_replication(
                    data_base_replicator=data_base_replicator, database=database
                )
    elif args["mode"] == "subscriptions_password_update":
        data_base_replicator.create_connection_pool()
        if (
            input(
                f"{bcolors.WARNING}IMPORTANT! Action will ALTER subscription with new passwords for "
                f"GREEN DB {green_db} no impact for BLUE DB {blue_db} "
            ).lower()
            == "yes"
        ):
            for database in blue_databases:
                data_base_replicator.alter_subscriptions_for_green_db(database)
    elif args["mode"] == "green_switchover":
        data_base_replicator.create_connection_pool()
        if (
            input(
                f"{bcolors.WARNING}IMPORTANT! Action will scale UP/DOWN {DB_POOL}, update ALL sequences remove "
                f"ALL publishers, replication slot from "
                f"{blue_db}, subscriptions from {green_db}, and revoke permissions from "
                f"postgres user from {blue_databases} "
                f"type yes to confirm:  {bcolors.ENDC}"
            ).lower()
            == "yes"
        ):
            start_time = time()
            kubernetes_scaler(0)
            if input("Change route53 record and confirm, yes: ").lower() == "yes":
                while data_base_replicator.check_dns():
                    logging.info("Waiting to change DNS record to non Vault DB")
                restart_ns(DB_POOL.keys())
            for i in range(LAG_CHECK_TIMES):
                logging.info(f"Checking DB lag, attempt {i}")
                data_base_replicator.check_lag(blue_databases, mode="Simple")
                optional_sleep(10)
            for database in blue_databases:
                clean_up_replication(
                    data_base_replicator=data_base_replicator, database=database
                )
                data_base_replicator.update_sequences(database=database)
            if (
                input(
                    f"{bcolors.WARNING} Please check route53 point to the green DB, type yes, "
                    f"when you reade scale up db connector: {bcolors.ENDC}"
                ).lower()
                == "yes"
            ):
                while not data_base_replicator.check_dns():
                    logging.info("Waiting to change DNS record to Vault DB")
                optional_sleep(10)
                kubernetes_scaler(3)
                restart_ns(DB_POOL.keys())
            logging.info(
                f"{bcolors.OKBLUE} Total down time {int(time() - start_time)} seconds"
            )
    elif args["mode"] == "recreate_pg_stat_statements":
        data_base_replicator.create_connection_pool()
        for database in blue_databases:
            data_base_replicator.recreate_pg_stat_statements(database)
    elif args["mode"] == "grant_pg_monitor":
        data_base_replicator.create_connection_pool()
        for database in blue_databases:
            data_base_replicator.grant_role(user=database, role="PG_MONITOR")
    elif args["mode"] == "update_sequences":
        data_base_replicator.create_connection_pool()
        for database in blue_databases:
            data_base_replicator.update_sequences(database)
    elif args["mode"] == "check_lag":
        data_base_replicator.create_connection_pool()
        data_base_replicator.check_lag(blue_databases, mode="Full")
    elif args["mode"] == "create_publishers_blue":
        if args["automated_mode"] or (
            input(
                f"{bcolors.WARNING}IMPORTANT! Action will create publisher and replication slots on blue DB {blue_db}: "
            ).lower()
            == "yes"
        ):
            create_publishers(
                data_base_replicator=data_base_replicator,
                databases=blue_databases,
            )
    elif args["mode"] == "drop_publishers_green":
        if args["automated_mode"] or (
            input(
                f"{bcolors.WARNING}IMPORTANT! Action will delete replication slots {green_db}: "
            ).lower()
            == "yes"
        ):
            delete_publishers(
                data_base_replicator=data_base_replicator,
                databases=blue_databases,
            )
    elif args["mode"] == "create_subscribers_green":
        if args["automated_mode"] or (
            input(
                f"{bcolors.WARNING}IMPORTANT! Action will create subscribers {green_db} to {blue_db} previously create publishers: "
            ).lower()
            == "yes"
        ):
            create_subscriptions(
                data_base_replicator=data_base_replicator,
                databases=blue_databases,
                slot_creation_delay=args["slot_creation_delay"],
                force_create=True,
            )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    boto3.set_stream_logger("boto3.resources", logging.WARNING)
    main()












#!/usr/bin/env bash

#first we deploy the contract
export VAULT_SERVICE_ACCOUNT_TOKEN=$(python icb-ledgers-banking-platform/utils/get_service_account_token.py)
cd contract_release
clu import manifest.yaml --config=clu_config.yaml --auth-token=$VAULT_SERVICE_ACCOUNT_TOKEN







#!/usr/bin/env bash

./install_contract.sh

nohup locust -f icb-ledgers-banking-platform/locust_files/locustfile.py --config icb-ledgers-banking-platform/locust_files/locust-master.conf --web-host=0.0.0.0 > /tmp/outputlocust.log 2>&1 &
python icb-ledgers-banking-platform/main.py

trap 'kill "${pid}"' INT TERM
sleep infinity &
pid="$!"
wait "${pid}"
