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
