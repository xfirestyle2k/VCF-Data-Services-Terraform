export DSMADMINAUTHDR=$(curl -k \
  -d '{"email":"XXXXXX@vmware.com", "password":"VMware1!"}' \
  -H "Content-Type: application/json" -X POST \
  -i -s \
  https://<your DSM FQDN or IP>/provider/session | grep "Authorization: Bearer ")

curl -k -s \
 -H "$DSMADMINAUTHDR" \
 -H 'Accept: application/vnd.vmware.dms-v1+octet-stream' \
 https://<your DSM FQDN or IP>/provider/gateway-kubeconfig > dsm-admin.kubeconfig

export KUBECONFIG=dsm-admin.kubeconfig


