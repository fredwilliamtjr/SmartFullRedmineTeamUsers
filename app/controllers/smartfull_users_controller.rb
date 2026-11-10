# frozen_string_literal: true

# Página "Usuários" do plugin. Quem tem a opção "Pode criar usuários" (ligada
# pelo admin) consegue, sem falar com o admin:
#   - listar os usuários dele (os que criou + os que o admin marcou para ele);
#   - criar conta nova, já colocada nos projetos escolhidos;
#   - editar nome, sobrenome, e-mail e projetos/papéis desses usuários;
#   - desativar (bloquear) e reativar esses usuários.
# Excluir NÃO existe aqui: bloquear preserva o histórico.
#
# Limites: só projetos de que o responsável é membro, só papéis liberados pelo
# admin, nunca usuários administradores, nunca a própria conta.
class SmartfullUsersController < ApplicationController
  menu_item :smartfull_users

  before_action :require_login
  before_action :authorize_creator
  before_action :load_choices
  before_action :find_managed_user, only: [:edit, :update, :lock, :unlock]

  require_sudo_mode :create, :update, :lock, :unlock

  # Únicos campos aceitos do formulário. O Redmine ainda filtra de novo via
  # safe_attributes (para não-admin, 'admin' e 'status' nunca passam, e o login
  # só é aceito em conta nova).
  PERMITTED_FIELDS = %i[login firstname lastname mail].freeze
  EDITABLE_FIELDS = %i[firstname lastname mail].freeze

  def index
    @users = RedmineSmartfullTeamUsers.managed_users(User.current)
    @memberships = visible_memberships(@users.map(&:id))
  end

  def new
    @user = User.new
    @role_ids = @allowed_roles.size == 1 ? [@allowed_roles.first.id] : []
    @project_ids = @available_projects.size == 1 ? [@available_projects.first.id] : []
  end

  def create
    @user = User.new(language: Setting.default_language,
                     mail_notification: Setting.default_notification_option)
    @user.safe_attributes = params.fetch(:user, {}).permit(*PERMITTED_FIELDS).to_h
    @user.login = @user.mail if @user.login.blank?

    # Definidos aqui, fora do formulário, depois do safe_attributes.
    @user.admin = false
    @user.status = User::STATUS_ACTIVE
    @user.generate_password = true
    @user.must_change_passwd = true
    @user.pref[RedmineSmartfullTeamUsers::MANAGER_KEY] = User.current.id.to_s

    read_selection
    return render(:new) unless selection_valid?

    if save_in_transaction { create_memberships }
      Mailer.deliver_account_information(@user, @user.password)
      log_action('criou', projects: selected_projects.map(&:identifier), roles: @role_ids)
      flash[:notice] = l(:notice_smartfull_team_users_created,
                         login: @user.login, mail: @user.mail,
                         projects: selected_projects.map(&:name).join(', '))
      redirect_to smartfull_users_path
    else
      render :new
    end
  end

  def edit
    allowed = @allowed_roles.map(&:id)
    # Só vem marcado o projeto em que a pessoa tem algum papel que o responsável
    # pode dar. Projeto só com papel dado pelo admin (ex.: Gerente) fica
    # desmarcado, para que salvar sem mexer não acrescente papel lá.
    current = (visible_memberships([@user.id])[@user.id] || []).select { |m| (m.role_ids & allowed).any? }
    @project_ids = current.map(&:project_id)
    @role_ids = current.flat_map(&:role_ids).uniq & allowed
  end

  def update
    @user.safe_attributes = params.fetch(:user, {}).permit(*EDITABLE_FIELDS).to_h
    @user.admin = false

    read_selection
    return render(:edit) unless selection_valid?

    if save_in_transaction { sync_memberships }
      log_action('editou', projects: selected_projects.map(&:identifier), roles: @role_ids)
      flash[:notice] = l(:notice_smartfull_user_updated, login: @user.login)
      redirect_to smartfull_users_path
    else
      render :edit
    end
  end

  def lock
    @user.lock!
    log_action('desativou')
    flash[:notice] = l(:notice_smartfull_user_locked, login: @user.login)
    redirect_to smartfull_users_path
  end

  def unlock
    @user.activate!
    log_action('reativou')
    flash[:notice] = l(:notice_smartfull_user_unlocked, login: @user.login)
    redirect_to smartfull_users_path
  end

  private

  def authorize_creator
    deny_access unless RedmineSmartfullTeamUsers.can_create_users?(User.current)
  end

  def load_choices
    @allowed_roles = RedmineSmartfullTeamUsers.allowed_roles
    @available_projects = RedmineSmartfullTeamUsers.available_projects(User.current)
  end

  # Só usuários da lista do responsável (nunca admin, nunca ele mesmo).
  def find_managed_user
    @user = RedmineSmartfullTeamUsers.managed_users(User.current).find { |u| u.id == params[:id].to_i }
    render_404 unless @user
  end

  # Só o que o responsável pode dar: papéis liberados pelo admin e projetos de
  # que ele é membro. Qualquer outro id enviado é descartado.
  def read_selection
    @role_ids = selected_ids(:role_ids) & @allowed_roles.map(&:id)
    @project_ids = selected_ids(:project_ids) & @available_projects.map(&:id)
  end

  def selection_valid?
    @user.valid?
    @user.errors.add(:base, l(:error_smartfull_team_users_no_role)) if @role_ids.empty?
    @user.errors.add(:base, l(:error_smartfull_team_users_no_project)) if @project_ids.empty?
    @user.errors.empty?
  end

  def selected_ids(key)
    Array(params[key]).map(&:to_i).uniq
  end

  def selected_projects
    @available_projects.select { |p| @project_ids.include?(p.id) }
  end

  # Vínculos do(s) usuário(s) só nos projetos que o responsável enxerga.
  def visible_memberships(user_ids)
    Member.where(user_id: user_ids, project_id: @available_projects.map(&:id))
          .preload(:project, :roles, :member_roles).group_by(&:user_id)
  end

  # Salva o usuário, as preferências e os vínculos juntos: se algo falhar,
  # nada fica.
  def save_in_transaction
    saved = false
    User.transaction do
      raise ActiveRecord::Rollback unless @user.save

      @user.pref.save!
      yield
      saved = true
    end
    saved
  rescue ActiveRecord::RecordInvalid => e
    @user.errors.add(:base, e.record.errors.full_messages.join(', '))
    false
  end

  def create_memberships
    @project_ids.each do |project_id|
      member = Member.new(project_id: project_id, principal: @user)
      member.role_ids = @role_ids
      member.save!
    end
  end

  # Ajusta os vínculos nos projetos que o responsável enxerga:
  #  - projeto marcado: os papéis liberados passam a ser os escolhidos; papéis
  #    que ele não pode dar (ex.: dados pelo admin) ficam como estão;
  #  - projeto desmarcado: tira só os papéis liberados; se não sobrar nenhum
  #    (e nenhum herdado de grupo), o vínculo é removido.
  # Projetos fora da visão dele não são tocados.
  def sync_memberships
    allowed = @allowed_roles.map(&:id)
    existing = visible_memberships([@user.id])[@user.id].to_a.index_by(&:project_id)

    @available_projects.each do |project|
      member = existing[project.id]
      if @project_ids.include?(project.id)
        member ||= Member.new(project: project, principal: @user)
        member.role_ids = (member.role_ids - allowed) + @role_ids
        member.save!
      elsif member
        remaining = member.role_ids - allowed
        if remaining.empty? && !member.any_inherited_role?
          member.destroy!
        else
          member.role_ids = remaining
          member.save!
        end
      end
    end
  end

  def log_action(action, projects: nil, roles: nil)
    msg = +"[smartfull_team_users] #{User.current.login} #{action} o usuário #{@user.login} (id #{@user.id})"
    msg << " nos projetos #{projects.inspect}" if projects
    msg << " com papéis #{roles.inspect}" if roles
    Rails.logger.info(msg)
  end
end
