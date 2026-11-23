# Privacy Fly — Sua Privacidade, Sua Liberdade

Projeto responsivo, HTML/CSS/JavaScript, pronto para importação na Vercel como site estático. Os dados demonstrativos são fictícios. A versão real utiliza Supabase (Auth, Postgres e Storage). Não oferece intermediação de serviços sexuais, pagamentos automáticos ou reservas.

## Executar agora

Na pasta `privacy-fly`, execute `python3 -m http.server 8080 --directory public` e abra `http://localhost:8080`. Também é possível usar o Live Server do VS Code.

Sem credenciais do Supabase, o site funciona em modo demonstrativo, com persistência local. Na página Entrar, selecione Administrador, Profissional ou Cliente. Não há login real no modo de demonstração, e nunca deve ser usado com dados privados ou reais.

## Ativar banco e autenticação reais

1. Crie um projeto Supabase novo.
2. Execute `supabase/schema.sql` no SQL Editor. O script cria tabelas e políticas de acesso (RLS), cadastro automático, visão pública de perfis aprovados e bucket de mídia.
3. Edite `public/config.js` com a URL do projeto e a chave pública publishable/anon. **Nunca use a chave service_role no navegador.**
4. Ative confirmação de e-mail e configure Site URL e Redirect URLs nas configurações de Auth, inclusive a URL de produção e o redirecionamento de recuperação. Configure um provedor SMTP de produção.
5. Cadastre uma conta normal e confirme seu e-mail. No SQL Editor, use o UUID real da conta para promovê-la a admin conforme o comentário ao final do schema. Não disponibilize cadastro de administradores no site público.
6. Cadastre uma conta profissional, crie o perfil, envie uma mídia de teste e valide aprovação e bloqueio no painel administrativo. Verifique que uma conta cliente não pode ler transações ou alterar funções.

## Publicar na Vercel

1. Faça upload do conteúdo desta pasta para um repositório Git privado (não inclua senhas ou chaves privadas).
2. Importe o repositório na Vercel. Framework Preset: Other. Root Directory: pasta que contém `vercel.json`. Output Directory: `public`. Build Command: vazio.
3. Configure e-mail e URL de produção no Supabase. Faça deploy e teste fluxos de cadastro, verificação, login, recuperação, aprovação, favoritos e upload.

## Funcionalidades

- Catálogo público com busca, categoria, cidade, perfil individual e favoritos.
- Área profissional com edição, status de moderação, foto principal, galeria de imagens e vídeos.
- Administração com receitas, despesas, lucro líquido, clientes habilitados, ativos/inativos, perfis e aprovação.
- Autenticação real por e-mail e senha quando configurada; roles protegidas por RLS.
- Lançamentos financeiros manuais, não conectados a um gateway; lucro calculado por receita menos despesa cadastrada.

## Limitações e checklist antes de produção

- A infraestrutura Supabase não está provisionada nem testada com credenciais reais neste ambiente. Valide o schema em projeto de homologação e execute testes de RLS antes de liberar o site.
- Arquivos são armazenados em bucket privado, com leitura autorizada para o dono, administrador ou perfil aprovado e URLs temporárias. Links já emitidos permanecem válidos por até 10 minutos. Implemente limpeza de arquivos órfãos e rotina de retenção antes de produção. O teste de upload pelo navegador da prévia não foi concluído; valide fotos e vídeos no Supabase antes do lançamento.
- Os seis retratos dos perfis fictícios foram gerados para a demonstração. Eles não representam prestadoras reais.
- Visualizações são estimativas, sem deduplicação ou proteção antifraude. Clientes ativos significa contas habilitadas, não usuários online.
- Após revisão de segurança, adicione CSP, monitoramento, limites de requisições, auditoria, termos e política de privacidade revisados.
- Confirme consentimento e direitos autorais de portfólio e proíba conteúdo ilícito/sexual explícito.
