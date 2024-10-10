VIADMINAUTHHDR=$(curl -k \
    -d '{"username":"'administrator@vsphere.local'", "password":"'VMware1!'"}' \
    -H "Content-Type: application/json" -X POST \
    -i -s \
    https://<your vCenter FQDN>/provider/plugin/session-using-vc-credentials | grep "Authorization: Bearer ")

curl -k -s \
 -H "$VIADMINAUTHHDR" \
 -H 'Accept: application/vnd.vmware.dms-v1+octet-stream' \
 https://<your vCenter FQDN>/provider/gateway-kubeconfig > dsm-viadmin.kubeconfig

export KUBECONFIG=dsm-viadmin.kubeconfig