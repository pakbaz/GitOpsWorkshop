# AKS
# Create resource group.
az group create --name "demo" --location "westus2"
# Create a new AKS Cluster with vm type standard_d2_v2
az aks create -g "demo" -n "cluster1" --node-count 1 --generate-ssh-keys --node-vm-size "standard_d2_v2"
# get credentials
az aks get-credentials -g "demo" -n "cluster1"


# Create Local cluster with k3d or kind
# k3d cluster create mycluster
kind create cluster
# Create connected cluster. accepted values for distribution tag: aks, aks_edge_k3s, aks_edge_k8s, aks_engine, aks_management, aks_workload, canonical, capz, eks, generic, gke, k3s, karbon, kind, minikube, openshift, rancher_rke, tkg
az connectedk8s connect -g "demo" -n "arc" -l "westus2" --distribution "kind"
# Create Service Account and Cluster Role Binding for Cluster-Admin Role
kubectl create serviceaccount demo-user -n default
kubectl create clusterrolebinding demo-user-binding --clusterrole cluster-admin --serviceaccount default:demo-user
# Create Secret for Service Account Token
kubectl apply -f demo-user-secret.yaml
# Create Token and Copy it to clipboard
$TOKEN = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret demo-user-secret -o jsonpath='{$.data.token}'))))
Set-Clipboard -Value $TOKEN


#GitOps with ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd -w

# Option1- Change SVC to Load Balancer For Azure
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
$Server = kubectl get services --namespace argocd argocd-server --output jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Option2- Port Forwarding for local cluster
kubectl port-forward svc/argocd-server -n argocd 8080:443
$Server = "localhost:8080"

$Password = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"))))
Set-Clipboard -Value $Password

argocd login $Server --username admin --password $Password --insecure

argocd app create voteapp --repo https://github.com/pakbaz/GitOpsWorkshop.git --path apps/vote-app --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app get voteapp
argocd app sync voteapp

kubectl create namespace shop
argocd app create sockshop --repo https://github.com/pakbaz/GitOpsWorkshop.git --path apps/sock-shop --dest-server https://kubernetes.default.svc --dest-namespace shop
argocd app get sockshop
argocd app sync sockshop

# Open Vote App Locally
kubectl port-forward svc/azure-vote-front 8081:80
$url = "localhost:8081"
# Open Vote app in azure by getting load balancer IP
$url = kubectl get svc azure-vote-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Start "http://$url"

argocd app delete voteapp


