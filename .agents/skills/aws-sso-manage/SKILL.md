---
name: aws-sso-manage
description: Manage AWS IAM Identity Center (SSO) users — create users, assign permission sets, remove IAM, send onboarding/migration emails via SES. Use this skill when onboarding new starters, changing roles, offboarding users, or auditing SSO access.
---

# AWS SSO User Management

## Key Identifiers

- **SSO Instance ARN:** `arn:aws:sso:::instance/ssoins-68041faa362c6274`
- **Identity Store ID:** `d-9367b36fef`
- **SSO Region:** `eu-west-1`
- **Portal URL:** `https://paperround.awsapps.com/start` (also accessible via `https://d-9367b36fef.awsapps.com/start`)
- **Main Account (PaperRound):** `474344676769`
- **Secondary Account (Non-PaperRound):** `977099013930`
- **SES Sender:** `james.rothwellhughes@newsteamgroup.co.uk`
- **SES CC:** `james.rothwellhughes@paperround.tech`
- **SES Region:** `eu-west-2`

## Username Convention

- SSO usernames use the `@paperround.tech` domain
- Format: `firstname.lastname@paperround.tech`
- Legacy IAM users were on `@paperround.net` (being phased out)

## Permission Sets

| Name | ARN | Typical Use |
|---|---|---|
| JuniorDeveloper | `ps-6804a576433065d7` | Junior/new developers, dev & QA only |
| Developer | `ps-fb5ac14dc8e729f9` | Mid-level developers |
| SeniorDeveloper | `ps-6804f66279b5f875` | Senior developers, broader env access |
| InsightsDeveloper | `ps-6804a6262f5313ba` | Data/insights focused access |
| ProductionSupport | `ps-68044b828e69ddab` | Prod incident response (ECS restart, Lambda invoke, SQS redrive, SSM sessions) |
| SecurityAdmin | `ps-680413133800c917` | Security tooling and audit |
| FinanceAdmin | `ps-6804585996d83231` | Billing and cost management |
| ReadOnlyAccess | `ps-90e313ba97c05d8a` | Read-only across services |
| AdministratorAccess | `ps-648f98be299a7032` | Full admin (leads only) |

All permission set ARNs share the prefix `arn:aws:sso:::permissionSet/ssoins-68041faa362c6274/`

## Important

- Always set `AWS_PAGER=""` or pass `--output json` to avoid paging in CLI calls.
- All SSO admin commands must target region `eu-west-1`.
- All SES email commands must target region `eu-west-2`.
- Never delete IAM users until the user has confirmed SSO access is working.
- Release branches are immutable — never modify them.

## Procedures

### 1. Create a New SSO User

```bash
AWS_PAGER="" aws identitystore create-user \
  --identity-store-id d-9367b36fef \
  --user-name 'firstname.lastname@paperround.tech' \
  --name '{"GivenName":"Firstname","FamilyName":"Lastname"}' \
  --display-name 'Firstname Lastname' \
  --emails '[{"Value":"firstname.lastname@paperround.tech","Type":"work","Primary":true}]' \
  --region eu-west-1 --output json
```

Note the returned `UserId` — it's needed for permission set assignment.

After creation, the user needs a password set via Identity Center console: **Users → select user → Reset password → Send email**.

### 2. Assign a Permission Set

```bash
AWS_PAGER="" aws sso-admin create-account-assignment \
  --instance-arn 'arn:aws:sso:::instance/ssoins-68041faa362c6274' \
  --target-id '<ACCOUNT_ID>' \
  --target-type AWS_ACCOUNT \
  --permission-set-arn 'arn:aws:sso:::permissionSet/ssoins-68041faa362c6274/<PS_ID>' \
  --principal-type USER \
  --principal-id '<USER_ID>' \
  --region eu-west-1 --output json
```

### 3. Remove a Permission Set

```bash
AWS_PAGER="" aws sso-admin delete-account-assignment \
  --instance-arn 'arn:aws:sso:::instance/ssoins-68041faa362c6274' \
  --target-id '<ACCOUNT_ID>' \
  --target-type AWS_ACCOUNT \
  --permission-set-arn 'arn:aws:sso:::permissionSet/ssoins-68041faa362c6274/<PS_ID>' \
  --principal-type USER \
  --principal-id '<USER_ID>' \
  --region eu-west-1 --output json
```

### 4. List a User's Roles

```bash
# Get user ID
AWS_PAGER="" aws identitystore list-users \
  --identity-store-id d-9367b36fef \
  --filters 'AttributePath=UserName,AttributeValue=firstname.lastname@paperround.tech' \
  --region eu-west-1 --output json

# List assignments
AWS_PAGER="" aws sso-admin list-account-assignments-for-principal \
  --instance-arn 'arn:aws:sso:::instance/ssoins-68041faa362c6274' \
  --principal-id '<USER_ID>' \
  --principal-type USER \
  --region eu-west-1 --output json
```

### 5. Remove Legacy IAM User

Only after the user has confirmed SSO access is working:

```bash
# Check for access keys first
AWS_PAGER="" aws iam list-access-keys --user-name 'user@paperround.net' --output json

# Delete keys if present
AWS_PAGER="" aws iam delete-access-key --user-name 'user@paperround.net' --access-key-id '<KEY_ID>'

# Remove from groups, detach policies, delete login profile, then delete user
AWS_PAGER="" aws iam delete-login-profile --user-name 'user@paperround.net'
AWS_PAGER="" aws iam delete-user --user-name 'user@paperround.net'
```

### 6. Delete SSO User (Offboarding)

```bash
# Remove all account assignments first (see step 3), then:
AWS_PAGER="" aws identitystore delete-user \
  --identity-store-id d-9367b36fef \
  --user-id '<USER_ID>' \
  --region eu-west-1
```

### 7. Audit All Users

Use a Python script to iterate all SSO users and their assignments:
- `identitystore list-users` to get all users
- `sso-admin list-account-assignments-for-principal` per user
- `iam get-user` / `iam list-access-keys` to check legacy IAM status
- Cross-reference to produce a status table

### 8. Send Onboarding/Welcome Email via SES

Emails should be sent from `james.rothwellhughes@newsteamgroup.co.uk`, CC'd to `james.rothwellhughes@paperround.tech`, via SES in `eu-west-2`.

The welcome email should include:
- Portal URL: `https://paperround.awsapps.com/start`
- Their login email (`@paperround.tech`)
- Their assigned roles and accounts
- CLI setup instructions (`aws configure sso` with session name `paperround`, start URL, region `eu-west-1`)
- Daily login command: `aws sso login --profile paperround`
- The `AWS_PROFILE=paperround` export tip
- The `--no-browser` option for headless/remote servers
- Contact James for any issues

### 9. Send Migration Email (IAM → SSO)

For existing users transitioning from IAM to SSO:
- Explain their SSO access is ready
- Include portal URL and login details
- List their assigned roles
- Ask them to test SSO and confirm it works
- Explain IAM access will be removed after confirmation
- Include CLI setup instructions as above

## Typical Role Assignments by Seniority

- **New starter / junior:** JuniorDeveloper on main account
- **Mid-level developer:** Developer on main account
- **Senior developer:** SeniorDeveloper + ProductionSupport on main account
- **Deputy lead (Nathan):** AdministratorAccess + SeniorDeveloper + ProductionSupport + SecurityAdmin + FinanceAdmin
- **Lead (James R-H):** AdministratorAccess on both accounts
- **Finance/non-technical:** FinanceAdmin or ReadOnlyAccess
- **External/contractor on secondary account:** Developer on secondary account only
