# EKS with Karpenter and Bottlerocket

Builds an EKS cluster where [Karpenter](https://karpenter.sh) provisions EC2 nodes running [Bottlerocket](https://github.com/bottlerocket-os/bottlerocket) AMIs.

## Components

- `vpc.tf` - VPC with private, public and intra subnets. Private subnets carry the `karpenter.sh/discovery` tag.
- `main.tf` - EKS cluster, a small Bottlerocket managed node group that runs the Karpenter controller, the Karpenter IAM/SQS resources (Pod Identity) and the Karpenter Helm release.
- `karpenter/` - `EC2NodeClass` (Bottlerocket) and `NodePool` manifests.
- `nginx/` - sample deployment that triggers a scale-up.

The controller runs on a managed node group rather than Fargate because EKS Pod Identity is not supported on Fargate.

## Usage

```sh
tofu init
tofu apply

# Configure kubectl
$(tofu output -raw kubeconfig_command)

# Create the node class and node pool
export CLUSTER_NAME=$(tofu output -raw cluster_name)
export NODE_ROLE=$(tofu output -raw node_iam_role_name)
envsubst < karpenter/node-class.yaml | kubectl apply -f -
kubectl apply -f karpenter/node-pool.yaml

# Trigger a scale-up and watch Karpenter launch a Bottlerocket node
kubectl apply -f nginx/deployment.yaml
kubectl get nodeclaims -w
kubectl get nodes -o wide   # OS image shows "Bottlerocket OS"
```

## Cleanup

Delete the workload and Karpenter resources first so Karpenter terminates the EC2 instances it created. Otherwise the VPC cannot be destroyed.

```sh
kubectl delete -f nginx/deployment.yaml
kubectl delete -f karpenter/node-pool.yaml
kubectl delete ec2nodeclass bottlerocket
tofu destroy
```
