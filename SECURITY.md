# Política de segurança

## Como reportar

Não abra issue pública para vulnerabilidades, credenciais expostas, kubeconfigs, tokens ou caminhos de ataque. Use [GitHub Security Advisories](https://github.com/opsteamhub/terraform-aws-eks/security/advisories/new). Se o recurso não estiver disponível, contate privadamente um mantenedor da organização OpsTeamHub e compartilhe apenas os dados mínimos necessários.

Informe a versão ou SHA afetada, impacto, pré-condições, reprodução segura e mitigação sugerida. Não inclua state Terraform, dados de clientes, credenciais reais ou provas executadas em produção.

## Escopo de suporte

Antes da primeira release v2, correções permanecem em `master`. Depois da publicação, a major mais recente será a linha suportada; manutenção de versões anteriores depende de decisão explícita dos mantenedores.

## Responsabilidade compartilhada

O módulo protege defaults, mas o consumidor é responsável por credenciais, backend/state, SCPs, permissões da identidade executora, seleção de subnets, rotas, security groups, DNS, acesso ao endpoint privado, roles externas, trust policies de workload, CIDRs permitidos, versões de add-ons, orçamento e validação em sua conta. Um exemplo funcional não substitui threat model, revisão do plan nem testes de acesso e interrupção.
