# IAM user with least privilege

An IAM user whose only permission is `sts:AssumeRole` on two roles created by this module:

- `<user_name>-read-only`: the AWS managed `ReadOnlyAccess` policy.
- `<user_name>-developer`: a scoped custom policy for EC2 and EKS deployment actions.

Both roles trust only the user's ARN. Session duration defaults to 3600 seconds.

> **Not tested against AWS.** The IAM behaviour of this module (the conditions, tag rules and role permissions) has not been tested against a real AWS account. It has only been checked with `tofu validate`. Review the policies and test in a non-production account before relying on them.

## Files

- `provider.tf`: provider and version constraints, plus `default_tags` (`project`, `provisioned_with`).
- `variables.tf`: input variables and their validation.
- `main.tf`: the user, the two roles, the developer policy and the user's assume-role policy.
- `outputs.tf`: ARNs and role-switch URLs.

## Usage

```sh
tofu init
tofu apply
```

## Variables

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `region` | `string` | `"ap-southeast-1"` | AWS region used by the provider and by the region conditions. |
| `user_name` | `string` | `"least-privilege-operator"` | IAM user name, 1 to 50 characters. Also the prefix of the role names. |
| `max_session_duration` | `number` | `3600` | Maximum session duration in seconds for both roles (3600 to 43200). |
| `ownership_tag_key` | `string` | `"managed_by"` | Tag key marking resources the developer role may manage. Must not start with `aws:`. |
| `ownership_tag_value` | `string` | `"developer-role"` | Tag value marking resources the developer role may manage. |
| `allowed_tag_keys` | `list(string)` | `["project", "provisioned_with"]` | Extra tag keys allowed at creation, besides the ownership key and `Name`. |
| `instance_profile_role_arns` | `list(string)` | `[]` | Role ARNs the developer role may pass to EC2. Wildcards are rejected. Empty means no `iam:PassRole`. |
| `eks_cluster_arns` | `list(string)` | `[]` | EKS cluster ARNs the developer role may modify. Wildcards are rejected. Empty means no mutating EKS access. |

### Tag keys and `default_tags`

The `ec2:CreateTags` permission only allows the ownership key, `Name` and the keys in `allowed_tag_keys`. The provider `default_tags` in `provider.tf` add `project` and `provisioned_with` to everything created, so those keys are in the `allowed_tag_keys` default. If you change `default_tags`, update `allowed_tag_keys` to match, or launches will fail with an authorization error.

## Outputs

| Name | Description |
| --- | --- |
| `user_arn` | ARN of the IAM user. |
| `read_only_role_arn` | ARN of the read-only role. |
| `developer_role_arn` | ARN of the developer role. |
| `read_only_switch_role_url` | Console URL that switches to the read-only role. |
| `developer_switch_role_url` | Console URL that switches to the developer role. |

## Developer role actions

- Instances and security groups must be created with the ownership tag (`ownership_tag_key` = `ownership_tag_value`). Creation without it is denied.
- Instance lifecycle actions (start, stop, reboot, terminate) and security group rule changes and deletion work only on resources that carry the ownership tag.
- Tags can only be set while creating a resource (`RunInstances`, `CreateSecurityGroup`), never on existing resources, and only with the allowed tag keys.
- `ec2:Describe*` is NOT limited to the configured region (some Describe calls are global). The EC2 write actions and the EKS read actions are limited to `region`.
- `iam:PassRole` is off by default. It is granted only for the roles in `instance_profile_role_arns`, and only to `ec2.amazonaws.com`.
- EKS mutation is off by default. With `eks_cluster_arns` set, the role gets `eks:AccessKubernetesApi` on those clusters and `eks:UpdateNodegroupConfig` on their nodegroups.

### EKS access entry

`eks:AccessKubernetesApi` alone does not grant Kubernetes permissions. The developer role must also be mapped inside each cluster with an EKS access entry (and an access policy or Kubernetes RBAC binding). This module does not create access entries.

## Read-only role

`ReadOnlyAccess` is broad. It can read data in S3 objects and in many other services (for example DynamoDB items, SQS messages and Secrets Manager metadata), not only resource configuration. Use a narrower policy if that is too much.

## Credentials and destroy

This module creates no access keys. It does not stop anyone with sufficient IAM rights from creating access keys for the user outside Terraform, and the user's own policy does not deny it. Create the console password outside Terraform too (IAM console, Security credentials, or `aws iam create-login-profile`), so it stays out of state.

The user has `force_destroy = true`, so `tofu destroy` also removes credentials created outside Terraform (login profile, access keys, MFA devices). Set it to `false` if you want destroy to fail instead.

## Sign in and switch roles

1. Create a console password for the user, as above.
2. Sign in as the user.
3. Open the `read_only_switch_role_url` or `developer_switch_role_url` output, or use Switch role in the console menu with the account ID and role name.
4. Confirm the read-only role is denied writes and the developer role is limited to the scoped actions.

## Notes

MFA is not enforced. To require it, add an `aws:MultiFactorAuthPresent` condition to the trust policy.
