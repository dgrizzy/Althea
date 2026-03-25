compose := "docker compose"

# Build and start OpenClaw stack
deploy:
    {{compose}} build openclaw-gateway
    {{compose}} up -d openclaw-gateway

# Start OpenClaw gateway
start:
    {{compose}} up -d openclaw-gateway

# Stop and remove local stack
stop:
    {{compose}} down

# Follow logs (default service: openclaw-gateway)
logs service="openclaw-gateway":
    {{compose}} logs -f --tail=200 {{service}}

# Run test suite
test:
    uv run --extra dev pytest

# Terraform init (default dir: infra/terraform)
infra-init dir="infra/terraform":
    cd {{dir}} && terraform init

# Terraform plan (default tfvars: terraform.tfvars)
infra-plan dir="infra/terraform" tfvars="terraform.tfvars":
    cd {{dir}} && terraform plan -var-file="{{tfvars}}"

# Terraform apply
infra-apply dir="infra/terraform" tfvars="terraform.tfvars":
    cd {{dir}} && terraform apply -var-file="{{tfvars}}"

# Terraform destroy
infra-destroy dir="infra/terraform" tfvars="terraform.tfvars":
    cd {{dir}} && terraform destroy -var-file="{{tfvars}}"

# Install NumPy in gcloud python for IAP tunnel throughput
iap-install-numpy:
    ./scripts/install_gcloud_numpy.sh

# SSH to VM through IAP with automatic troubleshoot fallback
iap-ssh instance project zone command="":
    if [ -n "{{command}}" ]; then ./scripts/gcloud_iap_ssh.sh "{{instance}}" "{{project}}" "{{zone}}" --command "{{command}}"; else ./scripts/gcloud_iap_ssh.sh "{{instance}}" "{{project}}" "{{zone}}"; fi

# Deploy from VM using IAP SSH with troubleshooting
gpu-deploy instance="transcription-service-dev" project="amplify-dev-483403" zone="us-central1-a" remote_dir="/opt/althea/app":
    ./scripts/gcloud_iap_ssh.sh "{{instance}}" "{{project}}" "{{zone}}" --command "cd {{remote_dir}} && just deploy"

# Inspect Terraform for VM/disk resources (local; requires terraform state)
openclaw-terraform-check:
    ./scripts/check-terraform-vm-state.sh

# Remote OpenClaw persistence diagnostics (run on VM via IAP SSH)
# Example: just openclaw-diagnose-remote instance=amplify-bots-vm project=my-proj zone=us-central1-a
openclaw-diagnose-remote instance project zone remote_dir="/opt/althea/app":
    ./scripts/gcloud_iap_ssh.sh "{{instance}}" "{{project}}" "{{zone}}" --command "cd {{remote_dir}} && sudo bash scripts/diagnose-openclaw-memory.sh"
