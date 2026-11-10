# SmartFull Redmine Team Users

`redmine_smartfull_team_users` — plugin para Redmine 7.0+.

Deixa um **não-administrador** cuidar sozinho das
contas da equipe dele: **criar, editar, desativar e reativar** — só nos
projetos de que ele é membro e sem virar administrador do Redmine.

Feito para o caso do William: o admin liga uma opção na conta dele e ele passa
a cadastrar e manter a equipe dele sem precisar do admin.

## Como funciona

### Admin
1. *Administração → Plugins → SmartFull Team Users → Configurar*:
   marca os **papéis** que podem ser dados (ex.: Desenvolvedor, Reportador).
   A mesma tela lista quem está com a opção ligada.
2. *Administração → Usuários → (responsável) → editar*: marca
   **"Pode criar usuários"**.
3. (Opcional) *Administração → Usuários → (qualquer usuário) → editar*: no
   campo **"Aparece na lista de"**, escolhe o responsável. Serve para colocar
   na lista do William contas que já existiam (criadas pelo admin).

### Responsável (ex.: William)
- Ganha o botão **"Usuários"** no menu do topo. A página lista os usuários
  dele: os que ele criou pelo plugin + os que o admin marcou para ele.
  Colunas: login, nome, e-mail, projetos (papéis), situação, última conexão.
- **Novo usuário**: nome, sobrenome, e-mail, login (opcional; em branco usa o
  e-mail), papéis e projetos. A conta nasce ativa, não-admin, com senha
  aleatória enviada por e-mail e troca obrigatória no primeiro acesso.
- **Editar**: nome, sobrenome, e-mail, papéis e projetos. Desmarcar um
  projeto tira a pessoa dele. Login não muda.
- **Desativar / Reativar**: bloqueia/desbloqueia o acesso (pede confirmação
  para desativar). O histórico fica.
- **Excluir não existe** no plugin — continua só com o admin.

O botão aparece **só** para quem tem a opção ligada; admin não ganha
automaticamente (se ligar a opção na própria conta, passa a ver, com todos os
projetos ativos).

## Limites (o que o responsável NÃO consegue)

- Mexer em quem não está na lista dele, em administradores (mesmo se
  marcados para ele) ou na própria conta → 404.
- Colocar alguém em projeto de que ele não é membro (ids enviados são
  descartados).
- Dar papel fora da lista liberada pelo admin.
- Tornar alguém administrador, mudar status pelo formulário ou trocar login
  (ignorados; o Redmine também bloqueia para não-admin).
- Mexer em papéis que só o admin deu: ao editar, papéis fora da lista
  liberada ficam como estão; projeto em que a pessoa só tem esse tipo de papel
  vem desmarcado e não é tocado.
- Ligar a opção "Pode criar usuários" ou o campo "Aparece na lista de" — só
  na edição de usuário do admin.

Cada ação vai pro log: `[smartfull_team_users] <quem> criou|editou|desativou|reativou o usuário ...`.

Observações:
- No Redmine o usuário é sempre global. As contas são contas normais; o que
  fica restrito é em quais projetos entram e quem as administra.
- Quem edita pode trocar o e-mail da pessoa — e, com isso, a recuperação de
  senha passa a ir para o e-mail novo. É poder de quem administra a conta.

## Onde as informações ficam guardadas

Nas preferências do usuário (`user_preferences.others`):
- `smartfull_can_create_users` = `'1'` na conta do responsável;
- `smartfull_manager_id` = id do responsável, na conta de cada usuário da lista.

Nenhuma das duas está entre os campos que o usuário edita em "Minha conta".
O plugin **não cria tabelas** e **não precisa** de `redmine:plugins:migrate`.
Remover o plugin não quebra nada: as chaves ficam esquecidas nas preferências.

Para os campos do admin, o plugin usa o hook `view_users_form` e acrescenta
(via `prepend`) um passo no `UsersController#update` que grava as opções — só
quando quem salva é admin, e o responsável escolhido precisa ter a opção
ligada.

## Instalação

O nome da pasta precisa ser exatamente `redmine_smartfull_team_users`.

```bash
cd /caminho/do/redmine/plugins
git clone https://github.com/fredwilliamtjr/SmartFullRedmineTeamUsers.git redmine_smartfull_team_users
```

Depois reinicie o Redmine. O plugin não cria tabelas: **não precisa** de
`redmine:plugins:migrate`. Confira em **Administração → Plugins** que
"SmartFull Team Users" aparece e configure como descrito acima.

Em Docker (imagem oficial), a pasta `plugins/` fica em
`/usr/src/redmine/plugins/` dentro do container.

## Testado em

Redmine 7.0.1 (imagem oficial `redmine:7.0.1`, Ruby 4.0, Rails 8.1): num
Redmine de teste e numa cópia do banco de produção (MySQL 8.0.44).

| Cenário | Resultado |
|---|---|
| Sem a opção (inclusive admin) | Sem botão; páginas e ações dão 403 |
| Tenta se dar a opção por "Minha conta" / pela tela de admin | Ignorado / 403 |
| Admin liga a opção | Botão "Usuários"; lista dele; só projetos de que é membro |
| Campo "Aparece na lista de" | Só oferece quem tem a opção; valor inválido é descartado |
| Criar | Entra na lista dele; projetos/papéis escolhidos; não-admin, ativo, troca de senha obrigatória, e-mail enviado |
| Editar (nome, e-mail, troca de projeto e papel) | Aplicado; força de admin/status/login e projeto alheio ignorados |
| Editar quem tem papel dado só pelo admin | Esse papel é preservado; salvar sem mexer não altera nada |
| Desativar / reativar | Status bloqueado / ativo; bloqueado não consegue entrar |
| Editar/desativar quem não é da lista, admin, ou a si mesmo | 404 |
| Admin marcado para a lista dele | Não aparece; desativar dá 404 |
| Admin desliga a opção | Botão some; páginas e ações dão 403 |
| Primeiro login da conta nova | Obrigado a trocar a senha |

## Licença

GPL v2 — a mesma do Redmine. Veja [LICENSE](LICENSE).
