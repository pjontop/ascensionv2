# frozen_string_literal: true

class User < ApplicationRecord
  has_many :sessions, dependent: :destroy

  enum :role, { user: 0, reviewer: 1, admin: 2, superadmin: 3 }

  def posthog_distinct_id
    email.presence || "user-#{id}"
  end
end