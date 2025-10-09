# AWS EKS Cluster

Módulo Terraform para criação e gerenciamento de clusters Amazon EKS (Elastic Kubernetes Service) com configuração avançada de node groups, addons e segurança.

## Funcionalidades

- ✅ Cluster EKS com configuração completa
- ✅ Node Groups gerenciados com Auto Scaling
- ✅ Addons EKS (CoreDNS, VPC CNI, kube-proxy)
- ✅ Criptografia de dados em repouso com KMS
- ✅ Logs do cluster no CloudWatch
- ✅ Launch Templates customizáveis
- ✅ Configuração de rede avançada
- ✅ IAM Roles e políticas automáticas
- ✅ Suporte a Spot Instances
- ✅ Taints e Labels nos nodes

## Uso Básico

```hcl
module "eks_cluster" {
  source = "github.com/opsteamhub/terraform-aws-eks"

  eks_config = {
    "production" = {
      control_plane = {
        name    = "my-eks-cluster"
        version = "1.27"
        
        vpc_config = {
          vpc_id                  = "vpc-12345678"
          subnet_ids              = ["subnet-12345", "subnet-67890"]
          endpoint_private_access = true
          endpoint_public_access  = true
          public_access_cidrs     = ["10.0.0.0/8"]
        }
        
        enabled_cluster_log_types = ["api", "audit", "authenticator"]
        
        encryption_config = {
          resources = ["secrets"]
          provider = {
            create = true
            kms_key_description = "EKS cluster encryption key"
          }
        }
      }
      
      node_groups = {
        "workers" = {
          instance_types = ["t3.medium", "t3.large"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 2
            min_size     = 1
            max_size     = 10
          }
          
          subnet_ids = ["subnet-12345", "subnet-67890"]
        }
      }
    }
  }
}
```

## Configuração de Rede

### Tags Recomendadas nas Subnets

Para os **load balancers** do Kubernetes funcionarem automaticamente, as subnets devem ter tags específicas:

```hcl
# Subnets privadas (para node groups)
resource "aws_subnet" "private" {
  # ... outras configurações
  
  tags = {
    "kubernetes.io/role/internal-elb"        = "1"
    "kubernetes.io/cluster/my-cluster-name"  = "shared"  # ou "owned"
  }
}

# Subnets públicas (para load balancers)
resource "aws_subnet" "public" {
  # ... outras configurações
  
  tags = {
    "kubernetes.io/role/elb"                 = "1"
    "kubernetes.io/cluster/my-cluster-name"  = "shared"  # ou "owned"
  }
}
```

## Configuração Avançada

### Control Plane

```hcl
control_plane = {
  name    = "production-eks"
  version = "1.27"
  
  # Configuração de rede
  vpc_config = {
    vpc_id                  = "vpc-12345678"
    subnet_ids              = ["subnet-private-1", "subnet-private-2"]
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = ["sg-12345678"]
  }
  
  # Logs do cluster
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  logs = {
    retention_in_days = 30
  }
  
  # Criptografia
  encryption_config = {
    resources = ["secrets"]
    provider = {
      create                  = true
      kms_key_description     = "EKS encryption key"
      enable_kms_key_rotation = true
    }
  }
  
  # Addons
  addons = [
    {
      addon_name    = "vpc-cni"
      addon_version = "v1.12.6-eksbuild.2"
      resolve_conflicts = "OVERWRITE"
    },
    {
      addon_name    = "coredns"
      addon_version = "v1.10.1-eksbuild.1"
      configuration_values = jsonencode({
        replicaCount = 4
        resources = {
          limits = {
            cpu    = "100m"
            memory = "150Mi"
          }
          requests = {
            cpu    = "30m"
            memory = "30Mi"
          }
        }
      })
    }
  ]
}
```

### Node Groups

```hcl
node_groups = {
  "system" = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    
    scaling_config = {
      desired_size = 2
      min_size     = 2
      max_size     = 4
    }
    
    labels = {
      "node-type" = "system"
      "workload"  = "system-pods"
    }
    
    taint = [
      {
        key    = "node-type"
        value  = "system"
        effect = "NO_SCHEDULE"
      }
    ]
  }
  
  "workers" = {
    instance_types = ["t3.large", "t3.xlarge"]
    capacity_type  = "SPOT"
    
    scaling_config = {
      desired_size = 3
      min_size     = 1
      max_size     = 20
    }
    
    # Launch Template customizado
    launch_template = {
      instance_requirements = {
        memory_mib = {
          min = 8192
        }
        vcpu_count = {
          min = 2
          max = 8
        }
        instance_generations = ["current"]
      }
      
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      ]
      
      metadata_options = {
        http_endpoint = "enabled"
        http_tokens   = "required"
        http_put_response_hop_limit = 2
      }
    }
  }
}
```

## Variáveis Principais

| Nome | Tipo | Descrição | Obrigatório |
|------|------|-----------|-------------|
| `eks_config` | map(object) | Configuração completa do cluster EKS | ✅ |

### Estrutura do `eks_config`

#### Control Plane
- `name` - Nome do cluster
- `version` - Versão do Kubernetes
- `vpc_config` - Configuração de rede
- `encryption_config` - Configuração de criptografia
- `addons` - Lista de addons do EKS
- `logs` - Configuração de logs

#### Node Groups
- `instance_types` - Tipos de instância EC2
- `capacity_type` - ON_DEMAND ou SPOT
- `scaling_config` - Configuração de Auto Scaling
- `launch_template` - Template de lançamento customizado
- `labels` - Labels do Kubernetes
- `taint` - Taints do Kubernetes

## Outputs

- `cluster_id` - ID do cluster EKS
- `cluster_arn` - ARN do cluster EKS
- `cluster_endpoint` - Endpoint do cluster
- `cluster_security_group_id` - Security Group do cluster
- `node_groups` - Informações dos node groups
- `cluster_certificate_authority_data` - Certificado CA do cluster

## Pré-requisitos

1. **VPC configurada** com subnets públicas e privadas
2. **Tags nas subnets** (opcionais, mas recomendadas para load balancers):
   ```
   # Para subnets privadas (internal load balancers)
   "kubernetes.io/role/internal-elb" = "1"
   "kubernetes.io/cluster/CLUSTER_NAME" = "shared"
   
   # Para subnets públicas (external load balancers)
   "kubernetes.io/role/elb" = "1"
   "kubernetes.io/cluster/CLUSTER_NAME" = "shared"
   ```
3. **Terraform** >= 1.0
4. **Provider AWS** >= 5.0
5. **Permissões IAM** adequadas

## Exemplos

Veja a pasta `test/` para exemplos completos de uso:

- **basic-cluster.tf** - Cluster básico com node group
- **production-ready.tf** - Configuração para produção
- **spot-instances.tf** - Usando Spot Instances
- **multi-nodegroup.tf** - Múltiplos node groups

## Segurança

- Criptografia de dados em repouso habilitada por padrão
- Logs de auditoria configurados
- Security Groups restritivos
- IAM Roles com princípio de menor privilégio
- Metadata service v2 obrigatório

## Monitoramento

- Logs do cluster enviados para CloudWatch
- Métricas de node groups
- Integração com AWS X-Ray
- Suporte a Prometheus/Grafana

## Licença

MIT License