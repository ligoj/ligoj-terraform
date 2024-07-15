# Introduction

![Architecture](architecture.png "Architecture")

This Terraform configuration creates an AWS infrastructure running Ligoj with HA.
The related services are:
- Fargate
- Athena serverless
- ALB
- WAF
- Cognito
- Lambda
- ACM

# Requirements

This architecture can be pricey due to RDS instances.

``` bash
terraform init -upgrade \
    -backend-config="bucket=ligoj-terraform-bucket" \
    -backend-config="key=ligoj.tfstate" \
    -backend-config="region=eu-west-1" \
    -backend-config="profile=ligoj"
```

# Execution

``` ini
# Sample file 'conf.auto.tfvars'
environment="prod"
profile="my_aws_account_profile"
dns_zone="internal.com"
dns="ligoj.internal.com"
cognito_reply="DO_NOT_REPLY<no-reply@internal.com>"
cognito_source_arn="arn:aws:ses:COGNITO_REGION:000000000000:identity/ligoj@internal.com"
cognito_from="Ligoj <ligoj@internal.com>"
cognito_email_filter = "(custom@external.com|.*@internal.com)"
cognito_email_filter_message = "Only internal staff can signup to this application"
cognito_admin = "ligoj-admin@internal.com"
```

# Terraform deployment

``` bash
terraform init -backend-config="profile=ligoj" -backend-config="profile=ligoj" -reconfigure
terraform apply -var-file="main.sample.tfvars" -var profile="ligoj" -auto-approve
```
