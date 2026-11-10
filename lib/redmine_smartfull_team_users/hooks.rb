# frozen_string_literal: true

module RedmineSmartfullTeamUsers
  # Mostra a caixa "Pode criar usuários" na edição do usuário (só para admin).
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_users_form, partial: 'hooks/smartfull_team_users/user_form'
  end
end
