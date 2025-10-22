#!/bin/bash
set -e
       
###############################################
# CONFIGURABLE VARIABLES
###############################################
MIRROR_DIR="/home/ec2-user/mirror"
MIRROR_REGISTRY_VERSION="1.3.11"
REGISTRY_PORT="8443"
USER_NAME="init"
PULL_SECRET_FILE="pull-secret.txt"
OC_MIRROR_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/oc-mirror.tar.gz"
       
###############################################
# DETECT RESUME FLAG (--continue)
###############################################
RESUME_MODE=false
if [[ "$1" == "--continue" ]]; then
RESUME_MODE=true
fi
       
###############################################
# STEP 1 - Install mirror registry 
###############################################
if [ "${RESUME_MODE}" = false ]; then
echo "[INFO] Installing dependencies and creating mirror directory..."
sudo yum install -y wget podman openssl jq
       
mkdir -p ${MIRROR_DIR}
cd ${MIRROR_DIR}
       
echo "[INFO] Downloading mirror-registry package..."
wget https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/mirror-registry/${MIRROR_REGISTRY_VERSION}/mirror-registry.tar.gz -O ${MIRROR_DIR}/mirror-registry.tar.gz
       
echo "[INFO] Extracting mirror-registry package..."
tar -xvf ${MIRROR_DIR}/mirror-registry.tar.gz -C ${MIRROR_DIR}/
       
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
echo "[INFO] Installing mirror registry on ${PUBLIC_HOSTNAME}:${REGISTRY_PORT} ..."
${MIRROR_DIR}/mirror-registry install --quayHostname ${PUBLIC_HOSTNAME} --quayRoot ${MIRROR_DIR}
       
echo "[INFO] Mirror registry installed successfully at https://${PUBLIC_HOSTNAME}:${REGISTRY_PORT}"
       
###############################################
# STEP 2 - Configure CA certificate trust
###############################################
echo "[INFO] Configuring system CA trust..."
sudo cp ${MIRROR_DIR}/quay-rootCA/rootCA.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
echo "[INFO] CA trust updated."
       
###############################################
# STEP 3 - Download and install oc-mirror
###############################################
echo "[INFO] Downloading oc-mirror tool..."
cd /tmp
curl -O ${OC_MIRROR_URL}
tar -xvf oc-mirror.tar.gz
chmod +x ./oc-mirror
sudo mv ./oc-mirror /usr/local/bin/
echo "[INFO] oc-mirror installed successfully."
       
###############################################
# STEP 4 - Manual Steps
###############################################
echo ""
echo "-----------------------------------------------"
echo "[ACTION REQUIRED]"
echo "1️⃣  Open your browser and log in to the mirror registry:"
echo "    https://${PUBLIC_HOSTNAME}:${REGISTRY_PORT}"
echo "    Username: ${USER_NAME}"
echo "    Password: (from installation output above)"
echo ""
echo "2️⃣  Go to: Account Settings → CLI Password → Generate Encrypted Password"
echo "    Copy the generated Podman login command and run it manually in this EC2 instance."
echo ""
echo "3️⃣  Download your OpenShift pull secret from:"
echo "    https://console.redhat.com/openshift/install/pull-secret"
echo "    and save it as: ${PULL_SECRET_FILE}"
echo "-----------------------------------------------"
echo ""
echo "[INFO] Once done, run this script again with:"
echo "       ./mirror-registry.sh --continue"
exit 0
fi
       
###############################################
# STEP 5 - pull secret
###############################################
echo "[INFO] Continuing setup from pull secret configuration..."
       
if [ ! -f "${PULL_SECRET_FILE}" ]; then
echo "[ERROR] Pull secret not found at ${PULL_SECRET_FILE}. Exiting."
exit 1
fi
       
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
       
echo "[INFO] Logging into the local mirror registry..."
podman login ${PUBLIC_HOSTNAME}:${REGISTRY_PORT}
       
echo "[INFO] Adding local registry credentials to pull-secret..."
podman login --authfile ${PULL_SECRET_FILE} ${PUBLIC_HOSTNAME}:${REGISTRY_PORT}
       
# Create final auth.json for containers
mkdir -p ${XDG_RUNTIME_DIR}/containers
cat ${PULL_SECRET_FILE} | jq . > ${XDG_RUNTIME_DIR}/containers/auth.json
       
echo "[INFO] Combined authentication file created at: ${XDG_RUNTIME_DIR}/containers/auth.json"
echo ""
cat ${XDG_RUNTIME_DIR}/containers/auth.json
       
###############################################
# DONE
###############################################
echo ""
echo "✅ Mirror registry and oc-mirror setup completed successfully!"
echo "Access your registry at: https://${PUBLIC_HOSTNAME}:${REGISTRY_PORT}"
echo "Authentication file: ${XDG_RUNTIME_DIR}/containers/auth.json"
