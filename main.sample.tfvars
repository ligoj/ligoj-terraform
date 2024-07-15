dns_zone="corp.com"
dns="ligoj.corp.com"
ligoj_version="3.2.3"
account="123456789012"
profile="my-profile"

# For steady phase
cpu=2
ram=8192

# For import phase
#cpu=4
#ram=8192
#aurora_min_capacity=16

cognito_dns="login.ligoj-rec.corp.com"
cognito_reply="DO_NOT_REPLY<no-reply@corp.com>"
cognito_source_arn="arn:aws:ses:eu-west-1:123456789012:identity/corp.com"
cognito_from="Ligoj <ligojs@corp.com>"
cognito_admin = "ligojs@corp.com"
cognito_email_filter = "(any_pattern|.*@corp.com)"
