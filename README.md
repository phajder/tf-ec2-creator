# **Terraform EC2 Generator Script**

This script automates the setup, management, and teardown of virtual machines in AWS EC2 service using **Terraform**. It ensures proper SSH key handling, updates Terraform variables, and dynamically maintains SSH configurations.

---

## **Prerequisites**

Before running the script, ensure that the following dependencies are installed:

- **Terraform** (>=1.0)
- **jq** (for JSON processing)
- **ssh-keygen** (for SSH key management)
- **grep** and **awk** (for text processing)

### **Installation of Dependencies**

To install terraform, please follow the official [documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) or download a [binary](https://developer.hashicorp.com/terraform/install).

#### **Linux (Debian/Ubuntu)**
```bash
sudo apt update && sudo apt install -y jq openssh-client
```

#### **MacOS (using Homebrew)**
```bash
brew install terraform jq
```

---

## **Configuration File (`config.env`)**

Before running the script, create a `config.env` file in the same directory with the following variables:

```bash
# Path to the Terraform project directory
INFRA_DIR="./infra"

# Terraform executable
TERRAFORM_CMD="terraform"

# Path to SSH key pair
SSH_KEY_PATH="$HOME/.ssh/terraform_key"

# Terraform variables file
TF_VARS_FILE="$INFRA_DIR/terraform.tfvars"

# Path to SSH configuration file
SSH_CONFIG_PATH="$HOME/.ssh/config"

# Terraform-managed SSH config file
TF_SSH_CONFIG_PATH="$HOME/.ssh/config_terraform"

# Default SSH user for connecting to instances
# "admin" for Debian, "ec2-user" for Amazon Linux, "ubuntu" for Ubuntu
SSH_USER="admin"
```

> **Important**: Adjust these variables to match your machine setup. In most of the cases, the defaults are fine.

---

## **Usage**

At the beginning set permissions to execute the script:

```bash
chmod u+x tf-ec2.sh
```

The script provides multiple commands to manage infrastructure. Run the script using:

```bash
./tf-ec2.sh <command>
```

### **Available Commands**
| Command   | Description |
|-----------|-------------|
| `generate` | Generates an SSH key (if not exists) and updates Terraform variables. |
| `create` | Initializes Terraform, applies configurations, and refreshes the Terraform state. |
| `refresh` | Refreshes Terraform state and updates SSH configurations. |
| `destroy` | Destroys all Terraform-managed resources and cleans up SSH configurations. |
| `reset` | Destroys and recreates the infrastructure. |

### **Example Usage**

1. **Generate SSH key and update Terraform variables**
   ```bash
   ./script.sh generate
   ```

2. **Create infrastructure**
   ```bash
   ./script.sh create
   ```

3. **Refresh Terraform state and update SSH config**
   ```bash
   ./script.sh refresh
   ```

4. **Destroy infrastructure**
   ```bash
   ./script.sh destroy
   ```

5. **Reset infrastructure (destroy and recreate)**
   ```bash
   ./script.sh reset
   ```

---

## **How It Works**

### **1. Dependency Check**
The script ensures that **Terraform, jq, ssh-keygen, grep, and awk** are installed. If any dependencies are missing, it exits with an error.

### **2. SSH Key Management**
- If an SSH key does not exist at `$SSH_KEY_PATH`, it generates a new **ed25519** key pair.
- The corresponding public key is stored in **Terraform variables**.

### **3. Terraform Execution**
- Runs `terraform init` and `terraform apply` to create infrastructure.
- After Terraform applies changes, the script **retrieves public IPs** of deployed instances.

### **4. SSH Configuration Update**
- Fetches instance IPs and dynamically updates `$TF_SSH_CONFIG_PATH`.
- Ensures that the main SSH config (`~/.ssh/config`) includes Terraform-managed instances.

### **5. Infrastructure Destruction**
- Requests user confirmation before running `terraform destroy`.
- Cleans up Terraform-generated SSH configurations.

---

## **Security Considerations**

- The SSH private key should be stored securely and not shared.
- The script modifies SSH config files (`~/.ssh/config`); review changes before running.
- Ensure that Terraform state files are properly secured.
- Generated key pair **is not** removed by the script. If the key has been compromised, it must be changed manually.
