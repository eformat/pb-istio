# Pet Battle Apps
PB_NAMESPACE ?= pet-battle
HELM_RELEASE_NAME ?= my
ISTIO_DOMAIN ?= apps.hivec.sandbox209.opentlc.com

create-pb-project:
	oc new-project "${PB_NAMESPACE}" || true

delete-pb-project:
	oc delete project "${PB_NAMESPACE}" || true

setup-charts:
	helm repo add petbattle https://petbattle.github.io/helm-charts
	helm repo update

define deploy-chart
$(eval chart := $(1))
$(eval chart_version := $(shell helm search repo petbattle/${chart} | head -2 | grep petbattle/$${chart} | awk '{print $$2}'))
helm fetch petbattle/${chart} --version ${chart_version}
helm templatbe ${HELM_RELEASE_NAME} ${chart}-${chart_version}.tgz --namespace ${PB_NAMESPACE} --set istio.enabled=true --set istio.domain=${ISTIO_DOMAIN} | oc apply -f- -n ${PB_NAMESPACE}
rm -f ${chart}-${chart_version}.tgz
endef

define undeploy-chart
$(eval chart := $(1))
$(eval chart_version := $(shell helm search repo petbattle/${chart} | head -2 | grep petbattle/$${chart} | awk '{print $$2}'))
helm fetch petbattle/${chart} --version ${chart_version}
helm template ${HELM_RELEASE_NAME} ${chart}-${chart_version}.tgz --namespace ${PB_NAMESPACE} --set istio.enabled=true --set istio.domain=${ISTIO_DOMAIN} | oc delete -f- -n ${PB_NAMESPACE}
rm -f ${chart}-${chart_version}.tgz
endef

define deploy-pb-api
$(call deploy-chart,pet-battle-api)
oc -n "${PB_NAMESPACE}" wait --for condition=available --timeout=120s deploymentconfig/${HELM_RELEASE_NAME}-pet-battle-api
endef

define undeploy-pb-api
$(call undeploy-chart,pet-battle-api)
endef

define deploy-pb-ui
$(call undeploy-chart,pet-battle)
endef

define undeploy-pb-ui
$(call undeploy-chart,pet-battle)
endef

deploy-pb-api: setup-charts create-pb-project
	$(call deploy-pb-api)

deploy-pb-ui: setup-charts create-pb-project
	$(call deploy-pb-ui)

undeploy-pb-api: setup-charts
	$(call undeploy-pb-api)

undeploy-pb-ui: setup-charts
	$(call undeploy-pb-ui)

# Istio using OLM
ISTIO_NAMESPACE ?= istio-system

define deploy-istio-control-plane
oc new-project "${ISTIO_NAMESPACE}" || true
oc apply -f ocp/kiali-subscription.yaml
oc apply -f ocp/jaeger-subscription.yaml
oc apply -f ocp/istio-subscription.yaml
sleep 60
oc -n openshift-operators wait --for condition=available --timeout=200s deployment/istio-operator
endef

define undeploy-istio-control-plane
$(eval kcsv := $(shell oc -n openshift-operators get subscription kiali-ossm -o jsonpath='{.status.installedCSV}'))
oc delete -f ocp/kiali-subscription.yaml || true
oc delete csv ${kcsv} -n openshift-operators --cascade=true || true
$(eval jcsv := $(shell oc -n openshift-operators get subscription jaeger-product -o jsonpath='{.status.installedCSV}'))
oc delete -f ocp/jaeger-subscription.yaml || true
oc delete csv ${jcsv} -n openshift-operators --cascade=true || true
$(eval icsv := $(shell oc -n openshift-operators get subscription servicemeshoperator -o jsonpath='{.status.installedCSV}'))
oc delete -f ocp/istio-subscription.yaml || true
oc delete csv ${icsv} -n openshift-operators --cascade=true || true
oc delete project "${ISTIO_NAMESPACE}" || true
endef

define deploy-istio-mesh
oc -n "${ISTIO_NAMESPACE}" apply -f ocp/istio-cr.yaml
sleep 10
oc -n ${ISTIO_NAMESPACE} wait --for condition=ready --timeout=600s smcp my-mesh
endef

define undeploy-istio-mesh
oc -n "${ISTIO_NAMESPACE}" delete -f ocp/istio-cr.yaml
endef

deploy-istio-control-plane:
	$(call deploy-istio-control-plane)

undeploy-istio-control-plane:
	$(call undeploy-istio-control-plane)

deploy-istio-mesh:
	$(call deploy-istio-mesh)

undeploy-istio-mesh:
	$(call undeploy-istio-mesh)
