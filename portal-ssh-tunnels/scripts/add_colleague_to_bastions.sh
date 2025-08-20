#!/bin/bash

# Script to add colleague's SSH key to all Portal bastion hosts
# Usage: ./add_colleague_to_bastions.sh "ssh-ed25519 AAAAC3... colleague@email.com"

if [ -z "$1" ]; then
    echo "Usage: $0 \"<colleague's public key>\""
    echo "Example: $0 \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... colleague@paperround.tech\""
    exit 1
fi

COLLEAGUE_PUBLIC_KEY="$1"

# Bastion hosts and their corresponding keys
declare -A BASTIONS=(
    ["qa"]="35.179.170.3:~/.ssh/bastion_key_qa"
    ["uat"]="18.175.239.214:~/.ssh/bastion_key_uat"
    ["staging"]="52.56.142.14:~/.ssh/bastion_key_staging"
    ["production"]="18.170.58.57:~/.ssh/bastion_key_production"
)

echo "Adding colleague's public key to all Portal bastion hosts..."
echo "Public key: ${COLLEAGUE_PUBLIC_KEY}"
echo ""

for env in "${!BASTIONS[@]}"; do
    IFS=':' read -r host keyfile <<< "${BASTIONS[$env]}"
    
    echo "Adding to $env bastion ($host)..."
    
    # Add the key to authorized_keys (append, don't overwrite)
    ssh -i "$keyfile" "ec2-user@$host" "echo '$COLLEAGUE_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully added to $env bastion"
        
        # Verify the key was added
        key_count=$(ssh -i "$keyfile" "ec2-user@$host" "wc -l < ~/.ssh/authorized_keys")
        echo "   Total keys now: $key_count"
    else
        echo "❌ Failed to add to $env bastion"
    fi
    echo ""
done

echo "Done! Your colleague should now be able to use their own private key to connect to all bastions."
echo ""
echo "They should update their tunnel scripts to use their key file:"
echo "  -i ~/.ssh/bastion_key_portal"
echo ""
echo "To verify access, your colleague can test:"
echo "  ssh -i ~/.ssh/bastion_key_portal ec2-user@35.179.170.3"
