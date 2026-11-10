# frozen_string_literal: true

Redmine::Plugin.register :redmine_smartfull_team_users do
  name 'SmartFull Team Users'
  author 'SmartFull'
  url 'https://github.com/fredwilliamtjr/SmartFullRedmineTeamUsers'
  description 'O admin liga, na conta de um usuário, a opção "Pode criar usuários". ' \
              'Esse usuário ganha a página "Usuários", onde cria, edita, desativa e ' \
              'reativa as contas da equipe dele, nos projetos de que é membro, sem ser ' \
              'administrador.'
  version '1.0.0'
  requires_redmine version_or_higher: '7.0.0'

  # Papéis que quem tem a opção pode dar às contas novas (definidos pelo admin).
  settings default: { 'role_ids' => [] },
           partial: 'settings/smartfull_team_users_settings'

  # Botão "Usuários" no menu do topo, só para quem tem a opção ligada.
  menu :top_menu, :smartfull_users,
       { controller: 'smartfull_users', action: 'index' },
       caption: :label_smartfull_users,
       after: :projects,
       if: proc { RedmineSmartfullTeamUsers.can_create_users?(User.current) }
end

# init.rb roda dentro do to_prepare do Redmine: aplica o patch e carrega os hooks.
UsersController.prepend(RedmineSmartfullTeamUsers::UsersControllerPatch) unless
  UsersController < RedmineSmartfullTeamUsers::UsersControllerPatch
RedmineSmartfullTeamUsers::Hooks
