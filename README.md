# Is it Observable
<p align="center"><img src="/image/logo.png" width="40%" alt="Is It observable Logo" /></p>

## Episode : What is Keptn LifeCycle Toolkit
This repository contains the files utilized during the tutorial presented in the dedicated IsItObservable episode related to Keptn LifeCycle Toolkit.
<p align="center"><img src="/image/keptn-logo.jpg" width="40%" alt="Keptn Logo" /></p>

What you will learn
* How to use the [Keptn LifeCycle Toolkit](https://github.com/keptn/lifecycle-toolkit)

This repository showcase the usage of Keptn LifeCycle Toolkit  with :
* The Otel-demo
* The OpenTelemetry Operator
* Nginx ingress controller
* Dynatrace
* ArgoCD

We will send all Telemetry data produced by the Otel-demo , and KLT to Dynatrace.

## Prerequisite
The following tools need to be install on your machine :
- jq
- kubectl
- git
- gcloud ( if you are using GKE)
- Helm


## Deployment Steps in GCP

You will first need a Kubernetes cluster with 2 Nodes.
You can either deploy on Minikube or K3s or follow the instructions to create GKE cluster:
### 1.Create a Google Cloud Platform Project
```shell
PROJECT_ID="<your-project-id>"
gcloud services enable container.googleapis.com --project ${PROJECT_ID}
gcloud services enable monitoring.googleapis.com \
    cloudtrace.googleapis.com \
    clouddebugger.googleapis.com \
    cloudprofiler.googleapis.com \
    --project ${PROJECT_ID}
```
### 2.Create a GKE cluster
```shell
ZONE=europe-west3-a
NAME=isitobservable-keptn-lifecycle-tookit
gcloud container clusters create "${NAME}" \
 --zone ${ZONE} --machine-type=e2-medium --num-nodes=3 --disk-type "pd-standard" --disk-size "10"
```


## Getting started
### Dynatrace Tenant
#### 1. Dynatrace Tenant - start a trial
If you don't have any Dyntrace tenant , then i suggest to create a trial using the following link : [Dynatrace Trial](https://bit.ly/3KxWDvY)
Once you have your Tenant save the Dynatrace (including https) tenant URL in the variable `DT_TENANT_URL` (for example : https://dedededfrf.live.dynatrace.com)
```
DT_TENANT_URL=<YOUR TENANT URL>
```

#### 2. Create the Dynatrace API Tokens
Create a Dynatrace token with the following scope ( left menu Acces Token):
* ingest metrics
* ingest OpenTelemetry traces
<p align="center"><img src="/image/data_ingest.png" width="40%" alt="data token" /></p>
Save the value of the token . We will use it later to store in a k8S secret

```
DATA_INGEST_TOKEN=<YOUR TOKEN VALUE>
```
### 3.Clone the Github Repository
```shell
https://github.com/isItObservable/keptn-lifecycle-Toolkit
cd keptn-lifecycle-Toolkit
```
### 4.Deploy most of the components
The application will deploy the otel demo v1.2.1
```shell
chmod 777 deployment.sh
./deployment.sh  --clustername "${NAME}" --dturl "${DT_TENANT_URL}" --dttoken "${DATA_INGEST_TOKEN}"
```

### 4. Deploy Keptn 
```shell
kubectl apply -f https://github.com/keptn/lifecycle-toolkit/releases/download/v0.5.0/manifest.yaml
```
### 5. Modify Keptn LifeCycle Toolkit
We will change the otel collector url define in the KLS in 2 deployments :

#### Update Deployment klc-controller-manager
```shell
kubectl edit deployment  klc-controller-manager -n keptn-lifecycle-toolkit-system
```
Change the `OTEL_COLLECTOR_URL` to use `oteld-collector.default.svc.cluster.local:4317`
#### Update Deployment keptn-scheduler
```shell
kubectl edit deployment  keptn-scheduler -n keptn-lifecycle-toolkit-system
```
Change the `OTEL_COLLECTOR_URL` to use `oteld-collector.default.svc.cluster.local:4317`

#### Add the Grafana Dashboard
```shell
kubectl apply -f keptn/grafana-dashboard-keptn-overview.yaml
kubectl apply -f keptn/grafana-dashboard-keptn-workloads.yaml
kubectl apply -f keptn/grafana_dashboard-keptn-application.yaml
```

### 6. Deploy the Otel-demo Application
```shell
kubectl create ns otel-demo
kubectl create keptn/application.yaml
kubectl apply -f kubernetes-manifests/openTelemetry-sidecar.yaml -n otel-demo
kubectl annotate ns otel-demo  keptn.sh/lifecycle-toolkit="enabled"
kubectl apply -f keptn/application.yaml
kubectl apply -f keptn/keptn-predeployment_adservice.yaml -n otel-demo
kubectl apply -f keptn-predeployment_cartservice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_checkoutservice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_currency.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_currency.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_frontend.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_kafka.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_paymentservice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_postgres.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_productcatalogserice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_recommendation.yaml  -n otel-demo
kubectl apply -f keptn/keptn-predeployment_redis.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_shipping.yaml -n otel-demo
```









