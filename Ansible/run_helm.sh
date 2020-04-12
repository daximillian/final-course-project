#!/usr/bin/env bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
git clone https://github.com/hashicorp/consul-helm.git
export KUBECONFIG=/home/ubuntu/kubeconfig_opsSchool-eks
helm install -f /home/ubuntu/helm-consul-values.yaml opsschool /home/ubuntu/consul-helm

kubectl create namespace monitoring
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
kubectl create -f grafana-dashboards.yml -n monitoring

helm install -f /home/ubuntu/prometheus-values.yml prometheus --namespace monitoring stable/prometheus 
helm install -f /home/ubuntu/grafana-values.yml grafana --namespace monitoring stable/grafana 

sleep 10s 

kubectl patch svc grafana --namespace monitoring -p '{"spec": {"type": "LoadBalancer"}}'

sleep 10s 

# kubectl patch svc prometheus-server --namespace monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# sleep 10s 

