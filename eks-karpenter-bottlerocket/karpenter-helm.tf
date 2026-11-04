# Installs the Karpenter controller; the module "karpenter" in main.tf provides its AWS resources
resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.6.0"
  wait             = true
  create_namespace = false

  # The Pod Identity association must exist before the controller pods start,
  # otherwise the pods are created without AWS credentials
  depends_on = [module.karpenter]

  values = [
    yamlencode({
      # A single controller node cannot satisfy the chart's pod anti-affinity for two replicas
      replicas = 1
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = module.karpenter.queue_name
      }
      serviceAccount = {
        name = module.karpenter.service_account
      }
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      ]
      nodeSelector = {
        "karpenter.sh/controller" = "true"
      }
    })
  ]
}
