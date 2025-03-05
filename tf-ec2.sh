#!/bin/bash

# Load configuration file
CONFIG_FILE="./config.env"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "[ERROR] Configuration file ($CONFIG_FILE) not found. Please create it."
    exit 1
fi

# SSH public key path (derived from private key)
SSH_PUBLIC_KEY_PATH="${SSH_KEY_PATH}.pub"

# Function to check if required dependencies are installed
check_dependencies() {
    REQUIRED_TOOLS=("terraform" "jq" "ssh-keygen" "grep", "awk")

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "[ERROR] Required tool '$tool' is not installed. Please install it and try again."
            exit 1
        fi
    done

    echo "[INFO] All required dependencies are installed."

    check_aws_configuration
}

# Function to check AWS configuration
check_aws_configuration() {
    AWS_CREDENTIALS_FILE="$HOME/.aws/credentials"
    AWS_CONFIG_FILE="$HOME/.aws/config"

    # Check if AWS credentials exist
    if [[ ! -f "$AWS_CREDENTIALS_FILE" ]] || [[ ! -f "$AWS_CONFIG_FILE" ]]; then
        echo "[ERROR] AWS credentials or config file not found in ~/.aws/"
        exit 1
    fi

     # Ensure Terraform variable file exists (to prevent first-run issues)
    if [[ ! -f "$TF_VARS_FILE" ]]; then
        echo "[INFO] Terraform variables file ($TF_VARS_FILE) does not exists. Creating with empty values."
        echo "public_key = \"\"" > "$TF_VARS_FILE"
    fi

    # Run Terraform init and apply just to test credentials
    if ! $TERRAFORM_CMD -chdir="$INFRA_DIR" init -backend=false &>/dev/null; then
        echo "[ERROR] Terraform initialization failed. Check your installation."
        exit 1
    fi

    if ! $TERRAFORM_CMD -chdir="$INFRA_DIR" apply -auto-approve -target=data.aws_caller_identity.current &>/dev/null; then
        echo "[ERROR] AWS authentication failed. Check your credentials in ~/.aws/."
        echo "Run 'aws configure' or set environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)."
        exit 1
    fi

    echo "[INFO] AWS credentials are valid."
}

# Generate SSH Key if not exists
generate_ssh_key() {
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "[INFO] Generating SSH key..."
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "Terraform Key"
        echo "[INFO] SSH key generated at $SSH_KEY_PATH"
    else
        echo "[INFO] SSH key already exists."
    fi

    update_tf_vars
}

# Update Terraform variables with public SSH key
update_tf_vars() {
    if [ ! -f "$SSH_PUBLIC_KEY_PATH" ]; then
        echo "[ERROR] Public key not found! Run 'generate' first."
        exit 1
    fi

    echo "[INFO] Updating Terraform variables with SSH key..."
    cat <<EOF > "$TF_VARS_FILE"
public_key = "$(cat $SSH_PUBLIC_KEY_PATH)"
EOF
    echo "[INFO] Terraform variable file updated: $TF_VARS_FILE"
}

# Initialize and apply Terraform scripts
create_infra() {
    generate_ssh_key
    echo "[INFO] Initializing Terraform..."
    $TERRAFORM_CMD -chdir="$INFRA_DIR" init
    echo "[INFO] Applying Terraform..."
    $TERRAFORM_CMD -chdir="$INFRA_DIR" apply -auto-approve
    refresh_state
}

# Refresh Terraform state
refresh_state() {
    echo "[INFO] Refreshing Terraform state..."
    $TERRAFORM_CMD -chdir="$INFRA_DIR" refresh
    update_ssh_config
}

# Destroy Terraform resources and clean up SSH config
destroy_infra() {
    echo "[WARNING] You are about to destroy all Terraform-managed resources!"
    echo "Type 'yes' to confirm:"
    read -r CONFIRMATION

    if [[ "$CONFIRMATION" != "yes" ]]; then
        echo "[INFO] Destruction cancelled."
        exit 0
    fi

    echo "[INFO] Destroying Terraform resources..."
    $TERRAFORM_CMD -chdir="$INFRA_DIR" destroy -auto-approve

    clean_ssh_config
    echo "[INFO] Infrastructure destroyed successfully."
}

# Reset infrastructure: destroy + create
reset_infra() {
    destroy_infra
    create_infra
}

# Update SSH Config with new IPs from Terraform state
update_ssh_config() {
    echo "[INFO] Fetching Terraform output..."
    
    VM_IPS=$($TERRAFORM_CMD -chdir="$INFRA_DIR" output -json public_ips | jq -r '.[]')

    if [[ -z "$VM_IPS" ]]; then
        echo "[ERROR] Failed to get IP addresses from Terraform state."
        exit 1
    fi

    echo "[INFO] Updating Terraform SSH config file: $TF_SSH_CONFIG_PATH"

    {
        echo "# Terraform Managed Start"
        index=1
        for ip in $VM_IPS; do
            if [[ -z "$ip" ]]; then
                echo "[WARNING] Skipping an entry with an empty IP. Check your AWS instance status."
                continue
            fi

            echo "Host terraform-vm-$index"
            echo "    HostName $ip"
            echo "    User $SSH_USER"
            echo "    IdentityFile $SSH_KEY_PATH"
            echo "    StrictHostKeyChecking no"
            echo ""
            ((index++))
        done
        echo "# Terraform Managed End"
    } > "$TF_SSH_CONFIG_PATH"

    echo "[INFO] Terraform SSH config updated."

    # Ensure SSH config file exists to prevent errors with grep
    if [[ ! -f "$SSH_CONFIG_PATH" ]]; then
        echo "[INFO] SSH config file does not exist. Creating SSH config file: $SSH_CONFIG_PATH"
        touch "$SSH_CONFIG_PATH"
    fi

    # Ensure SSH config includes our Terraform config for Host matching
    if ! grep -q "Host terraform-vm-*" "$SSH_CONFIG_PATH"; then
        echo "[INFO] Adding Host directive to main SSH config."
        {
            echo ""
            echo "# Terraform Managed Host Include"
            echo "Host terraform-vm-*"
            echo "    Include $TF_SSH_CONFIG_PATH"
        } >> "$SSH_CONFIG_PATH"
    fi
}

# Clean up Terraform-generated SSH config
clean_ssh_config() {
    if [[ -f "$TF_SSH_CONFIG_PATH" ]]; then
        echo "[INFO] Removing Terraform SSH config file: $TF_SSH_CONFIG_PATH"
        rm -f "$TF_SSH_CONFIG_PATH"
    fi

    # Ensure SSH config exists before modifying
    if [[ -f "$SSH_CONFIG_PATH" ]]; then
        echo "[INFO] Cleaning up Terraform Include directive from main SSH config."

        # Remove the "Host terraform-vm-*" block from SSH config
        awk '
            /# Terraform Managed Host Include/ {skip=1; next}
            skip && /^Host / {skip=0}
            !skip
        ' "$SSH_CONFIG_PATH" > "$SSH_CONFIG_PATH.tmp" && mv "$SSH_CONFIG_PATH.tmp" "$SSH_CONFIG_PATH"
    fi
}

# Help function
help_menu() {
    echo "Usage: $0 {generate|create|refresh|destroy|reset}"
    echo "Commands:"
    echo "  generate  - Generate SSH key and update Terraform variables"
    echo "  create    - Create infrastructure"
    echo "  refresh   - Refresh Terraform state and update SSH config"
    echo "  destroy   - Destroy infrastructure and clean up SSH config"
    echo "  reset     - Refresh state and destroy resources"
}

# Run sanity check first
check_dependencies

# Main execution
case "$1" in
    generate) generate_ssh_key ;;
    create) create_infra ;;
    refresh) refresh_state ;;
    destroy) destroy_infra ;;
    reset) reset_infra ;;
    *) help_menu ;;
esac
