# frozen_string_literal: true

module RedmineSmartfullTeamUsers
  # Grava as opções do plugin quando o admin salva a edição de um usuário
  # (Administração → Usuários → editar):
  #   - "Pode criar usuários"            (smartfull_can_create_users)
  #   - "Aparece na lista de usuários de" (smartfull_manager_id)
  # O UsersController do Redmine já exige admin para essa ação; a checagem aqui
  # é uma segunda trava. Os valores vão para as preferências do usuário, que o
  # Redmine salva logo depois de salvar o usuário (UsersController#update →
  # @user.pref.save).
  module UsersControllerPatch
    def update
      if User.current.admin? && @user
        if params.key?(:smartfull_can_create_users)
          value = params[:smartfull_can_create_users].to_s == '1' ? '1' : '0'
          @user.pref[RedmineSmartfullTeamUsers::PREF_KEY] = value
        end
        if params.key?(:smartfull_manager_id)
          @user.pref[RedmineSmartfullTeamUsers::MANAGER_KEY] = valid_smartfull_manager_id
        end
      end
      super
    end

    private

    # Só aceita um usuário que tenha a opção ligada (e não o próprio usuário).
    def valid_smartfull_manager_id
      id = params[:smartfull_manager_id].to_i
      return nil unless id.positive? && id != @user.id

      manager = User.find_by(id: id)
      manager && RedmineSmartfullTeamUsers.enabled_for?(manager) ? id.to_s : nil
    end
  end
end
