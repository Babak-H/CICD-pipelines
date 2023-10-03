# we have to save "kubeconfig" file for the gitlab-user as a "file variable" in the group variables so it is shared by all projects
# this will allow the gitlab runner to access the cluster from the runner's machine

# download config file of cluster from cloud provider and limit its accesses
chmod 400 my-microservice-kubeconfig.yaml
# export it, so we can use kubectl through this file
export KUBECONFIG=C:\\Users\\Babak\\Downloads\\my-microservice-kubeconfig.yaml
# get information about cluster
kubectl cluster-info
# get current namespaces
kubectl get namespace
# create new namespace for this cluster
kubectl create namespace my-microservice
# see if created
kubectl get namespace
# create a service account for gitlab-user, so it will have less accesses than admin
kubectl create serviceaccount cicd-service --namespace=my-microservice
# create role
nano cicd-role.yml

#############################################
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: my-micro-service
  name: cicd
rules:
- apiGroups: [""] # indicates the core API group
  resources: ["pods", "services", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
#############################################

# apply the role
kubectl apply -f cicd-role.yml
# bind the role to new namespace and service account
kubectl create rolebinding cicd-rb  --role=cicd-role --serviceaccount=my-microservice:cicd-service --namespace=my-microservice
# get information about the token for the service account
kubectl get serviceaccount cicd-service -n my-microservice -o yaml
# get the service account's secret file
kubectl get secret cicd-service-token-pvmkp -n my-microservice -o yaml
# decode the token
echo <SECRET_TOKEN> | base64 -d
# edit the old KUBECONFIG file, change user's name and the token to service account's toke, and also change file's name then re-export KUBECONFIG variable
export KUBECONFIG=C:\\Users\\Babak\\Downloads\\cicd-kubeconfig.yaml
# now we should get error that we don't have permissions here
kubectl get namespace
# but this one should work :)
kubectl get pods -n my-microservice

