# Contribuindo

## Preparação

Use Terraform 1.7 ou superior. A CI fixa as versões exatas das ferramentas. Os testes locais usam providers mockados e não precisam de credenciais AWS.

```bash
terraform init -backend=false -input=false
terraform validate
terraform test -test-directory=testing
```

Não adicione provider ou backend ao módulo raiz. Exemplos devem permanecer sem backend remoto, segredos, kubeconfig ou identificadores de clientes.

## Desenvolvimento

1. Abra uma branch curta a partir de `master`.
2. Preserve endereços Terraform ou documente a migração em `docs/MIGRATION-v2.md`.
3. Atualize `variables.tf`, `docs/CONFIGURATION.md` e exemplos ao alterar o contrato.
4. Adicione teste positivo e negativo para validations e combinações novas.
5. Registre mudanças de consumo em `CHANGELOG.md`.
6. Use Conventional Commits em inglês.

## Verificação

Execute todos os comandos de [AGENTS.md](AGENTS.md). Mocks validam o contrato e o grafo, mas uma release major ainda exige plan/apply controlado em uma conta sandbox, com VPC real, conectividade privada e workloads descartáveis.

## Pull request

O PR deve explicar comportamento, compatibilidade, segurança, custo, testes, impacto no state e rollback. Inclua o resultado de um plan de sandbox quando nomes, rede, IAM, KMS, add-ons, versões ou node groups puderem mudar. Não publique tag/release antes de aprovação e merge.
