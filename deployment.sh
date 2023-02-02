#!/usr/bin/env bash

################################################################################
### Script deploying the Observ-K8s environment
### Parameters:
### Clustern name: name of your k8s cluster
### dttoken: Dynatrace api token with ingest metrics and otlp ingest scope
### dturl : url of your DT tenant wihtout any / at the end for example: https://dedede.live.dynatrace.com
################################################################################


### Pre-flight checks for dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "Please install jq before continuing"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Please install git before continuing"
    exit 1
fi


if ! command -v helm >/dev/null 2>&1; then
    echo "Please install helm before continuing"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Please install kubectl before continuing"
    exit 1
fi
echo "parsing arguments"
while [ $# -gt 0 ]; do
  case "$1" in
  --dttoken)
    DTTOKEN="$2"
   shift 2
    ;;
  --dturl)
    DTURL="$2"
   shift 2
    ;;
  --clustername)
    CLUSTERNAME="$2"
   shift 2
    ;;
  *)
    echo "Warning: skipping unsupported option: $1"
    shift
    ;;
  esac
done
echo "Checking arguments"
if [ -z "$CLUSTERNAME" ]; then
  echo "Error: clustername not set!"
  exit 1
fi
if [ -z "$DTURL" ]; then
  echo "Error: environment-url not set!"
  exit 1
fi

if [ -z "$DTTOKEN" ]; then
  echo "Error: api-token not set!"
  exit 1
fi



helm upgrade --install ingress-nginx ingress-nginx  --repo https://kubernetes.github.io/ingress-nginx  --namespace ingress-nginx --create-namespace

### get the ip adress of ingress ####
IP=""
while [ -z $IP ]; do
  echo "Waiting for external IP"
  IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -ojson | jq -j '.status.loadBalancer.ingress[].ip')
  [ -z "$IP" ] && sleep 10
done
echo 'Found external IP: '$IP

### Update the ip of the ip adress for the ingres
#TODO to update this part to use the dns entry /ELB/ALB
sed -i "s,IP_TO_REPLACE,$IP," keptn/v1/K8sdemo.yaml
sed -i "s,IP_TO_REPLACE,$IP," keptn/v2/K8sdemo.yaml
sed -i "s,IP_TO_REPLACE,$IP," grafana/ingress.yaml

### Depploy Prometheus

#### Deploy the cert-manager
echo "Deploying Cert Manager ( for OpenTelemetry Operator)"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.yaml
# Wait for pod webhook started
kubectl wait pod -l app.kubernetes.io/component=webhook -n cert-manager --for=condition=Ready --timeout=2m
# Deploy the opentelemetry operator
sleep 10
echo "Deploying the OpenTelemetry Operator"
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
echo "Deploying the KLT"
kubectl apply -f https://github.com/keptn/lifecycle-toolkit/releases/download/v0.5.0/manifest.yaml

CLUSTERID=$(kubectl get namespace kube-system -o jsonpath='{.metadata.uid}')
sed -i "s,CLUSTER_ID_TOREPLACE,$CLUSTERID," kubernetes-manifests/openTelemetry-sidecar.yaml
sed -i "s,CLUSTER_NAME_TO_REPLACE,$CLUSTERNAME," kubernetes-manifests/openTelemetry-sidecar.yaml

#Deploy the OpenTelemetry Collector
echo "Deploying Otel Collector"
kubectl apply -f kubernetes-manifests/rbac.yaml
##update the collector pipeline
sed -i "s,DT_TOKEN_TO_REPLACE,$DTTOKEN," kubernetes-manifests/openTelemetry-manifest_prometheus.yaml
sed -i "s,DT_URL_TO_REPLACE,$DTURL," kubernetes-manifests/openTelemetry-manifest_prometheus.yaml
##Deploy the Collector DaemonSet
kubectl apply -f kubernetes-manifests/openTelemetry-manifest_prometheus.yaml

#install prometheus operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack  --set grafana.sidecar.dashboards.enabled=true
kubectl wait pod --namespace default -l "release=prometheus" --for=condition=Ready --timeout=2m
PROMETHEUS_SERVER=$(kubectl get svc -l app=kube-prometheus-stack-prometheus -o jsonpath="{.items[0].metadata.name}")
sed -i "s,PROMETHEUS_SERVER_TO_REPLACE,$PROMETHEUS_SERVER," keptn/v2/provider.yaml

PASSWORD_GRAFANA=$(kubectl get secret --namespace default prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
USER_GRAFANA=$(kubectl get secret --namespace default prometheus-grafana -o jsonpath="{.data.admin-user}" | base64 --decode)
kubectl apply -f grafana/ingress.yaml
kubectl apply -f keptn/ServiceMonitor.yaml
# Echo environ*
echo "--------------Demo--------------------"
echo "url of the demo: "
echo "Otel demo url: http://otel-demo.$IP.nip.io"
echo "--------------Pyroscope--------------------"
echo "grafana : http://grafana.$IP.nip.io"
echo " user:$USER_GRAFANA"
echo " password:$PASSWORD_GRAFANA"
echo "========================================================"


