# frozen_string_literal: true

# Regras centrais do plugin: quem pode criar usuários, em quais projetos,
# com quais papéis, e quais usuários aparecem na lista de cada responsável.
module RedmineSmartfullTeamUsers
  # Chaves guardadas nas preferências do usuário (user_preferences.others).
  # Nenhuma está na lista de safe_attributes do UserPreference, então o próprio
  # usuário não consegue mudá-las em "Minha conta": só o código do plugin
  # (na criação pela tela do plugin, ou quando um admin salva a edição do usuário).
  PREF_KEY = :smartfull_can_create_users # '1' = pode criar usuários
  MANAGER_KEY = :smartfull_manager_id    # id de quem vê este usuário na lista

  module_function

  # Opção ligada pelo admin na conta do usuário.
  def enabled_for?(user)
    user.is_a?(User) && user.pref[PREF_KEY].to_s == '1'
  end

  # Pode usar a página "Usuários" do plugin: só usuário ativo com a opção ligada.
  # Admin NÃO ganha automaticamente (ele já cria usuários pela Administração);
  # se um admin ligar a opção na própria conta, aí passa a ver o botão.
  def can_create_users?(user)
    return false unless user.is_a?(User) && user.logged? && user.active?

    enabled_for?(user)
  end

  # Projetos que a pessoa enxerga como membro (ativos). Admin vê todos os ativos.
  # Projetos públicos em que ela NÃO é membro ficam de fora.
  def available_projects(user)
    scope = Project.where(status: Project::STATUS_ACTIVE)
    scope = scope.where(id: user.memberships.select(:project_id)) unless user.admin?
    scope.order(:lft).to_a
  end

  # Papéis que o admin liberou na configuração do plugin.
  def allowed_roles
    ids = Array((Setting.plugin_redmine_smartfull_team_users || {})['role_ids']).map(&:to_i)
    Role.givable.where(id: ids).to_a
  end

  # Usuários com a opção ligada (para o admin conferir e escolher responsável).
  def enabled_users
    User.active.preload(:preference).sorted.select { |u| enabled_for?(u) }
  end

  # Id do responsável gravado no usuário (nil se não tiver).
  def manager_id(user)
    id = user.pref[MANAGER_KEY].to_i
    id.positive? ? id : nil
  end

  # Usuários que aparecem na lista de `manager` (e que ele pode editar e
  # desativar): os que ele criou pelo plugin e os que o admin marcou para ele.
  # Nunca administradores, nunca ele mesmo. Inclui bloqueados (para reativar).
  # Lista pequena; filtra em Ruby porque o valor fica serializado dentro de
  # user_preferences.others.
  def managed_users(manager)
    User.where(type: 'User', admin: false).where.not(id: manager.id).preload(:preference)
        .sorted.select { |u| manager_id(u) == manager.id }
  end
end
