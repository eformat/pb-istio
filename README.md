## istio

Deploy pet battle apps with istio

```bash
export PB_NAMESPACE= pet-battle
export HELM_RELEASE_NAME=my
export ISTIO_DOMAIN=apps.hivec.sandbox209.opentlc.com

make deploy-istio-control-plane
make deploy-istio-mesh
make deploy-pb-api
make deploy-pb-ui
```
