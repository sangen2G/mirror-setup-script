###############################################
        V2 oc-mirror operations
###############################################
echo ""
echo "-----------------------------------------------"
echo "[INFO] Starting oc-mirror v2 operations..."
echo "-----------------------------------------------"
echo ""

# Define variables
ISC_CONFIG=isc.yaml
REGISTRY_PORT="8443"
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
MIRROR_REGISTRY_URL="${PUBLIC_HOSTNAME}:${REGISTRY_PORT}"
WORKSPACE_DIR="testing"

# Prompt user to enter or paste ISC YAML content
echo ""
echo "[ACTION REQUIRED] Please paste your ISC YAML configuration below."
echo "Press ENTER and when done, press CTRL+D to save and continue."
echo "---------------------------------------------------------------"
cat > ${ISC_CONFIG}

echo ""
echo "[INFO] isc.yaml file saved at: ${ISC_CONFIG}"
echo ""
echo "[INFO] Validating isc.yaml content..."
echo "---------------------------------------------------------------"
cat ${ISC_CONFIG}
echo "---------------------------------------------------------------"
echo ""

# Confirm with user before proceeding
read -p "Proceed with oc-mirror operations using this configuration? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "[INFO] Aborting as per user input."
  exit 1
fi

# Ask user which environment type they want to run
echo ""
echo "Choose the type of mirroring to perform:"
echo "1️⃣  Partially Disconnected (directly to registry)"
echo "2️⃣  Fully Disconnected (mirror to disk, then from disk to registry)"
echo ""
read -p "Enter choice (1 or 2): " CHOICE

case "$CHOICE" in
  1)
    echo ""
    echo "[INFO] Running Partially Disconnected Mirroring..."
    echo "Command: oc-mirror -c ${ISC_CONFIG} --workspace file://${WORKSPACE_DIR} docker://${MIRROR_REGISTRY_URL} --v2"
    oc-mirror -c ${ISC_CONFIG} --workspace file://${WORKSPACE_DIR} docker://${MIRROR_REGISTRY_URL} --v2
    ;;
  2)
    echo ""
    echo "[INFO] Running Fully Disconnected Mirroring..."
    echo "[STEP 1] Mirror to disk:"
    echo "Command: oc-mirror -c ${ISC_CONFIG} file://${WORKSPACE_DIR} --v2"
    oc-mirror -c ${ISC_CONFIG} file://${WORKSPACE_DIR} --v2

    echo ""
    echo "[STEP 2] Mirror from disk to registry:"
    echo "Command: oc-mirror -c ${ISC_CONFIG} --from file://${WORKSPACE_DIR} docker://${MIRROR_REGISTRY_URL} --v2"
    oc-mirror -c ${ISC_CONFIG} --from file://${WORKSPACE_DIR} docker://${MIRROR_REGISTRY_URL} --v2
    ;;
  *)
    echo "[ERROR] Invalid choice. Please rerun and choose either 1 or 2."
    exit 1
    ;;
esac

echo ""
echo "✅ oc-mirror v2 operation completed successfully!"
echo "Mirroring completed for the selected environment type."
