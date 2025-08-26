# frozen_string_literal: true

class ChannelPolicy < ApplicationPolicy

  def index?
    app_user?
  end

  def show?
    app_user?
  end

  def new?
    any_manage?
  end

  def create?
    any_manage?
  end

  def edit?
    any_manage?
  end

  def update?
    any_manage?
  end

  def destroy?
    any_manage?
  end

  def destroy_releases?
    any_manage?
  end

  def versions?
    return true if enabled_auth?

    app_user?
  end

  def branches?
    return true if enabled_auth?

    app_user?
  end

  def release_types?
    return true if enabled_auth?

    app_user?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def enabled_auth?
    record.password.present?
  end

  def app_user?
    guest_mode? || any_manage? || app_collaborator?(user, app)
  end

  def any_manage?
    manage? || manage?(app: app)
  end

  def app
    @app ||= record.app
  end
end
