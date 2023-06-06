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

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

$Server = kubectl get services --namespace argocd argocd-server --output jsonpath='{.status.loadBalancer.ingress[0].ip}'

$Password = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"))))

argocd login $Server --username admin --password $Password --insecure

argocd app create voteapp --repo https://github.com/pakbaz/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

argocd app get guestbook

argocd app sync guestbook

argocd app delete guestbook