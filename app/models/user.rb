# frozen_string_literal: true

class User < ApplicationRecord
  has_many :sessions, dependent: :destroy

  def posthog_distinct_id
    email.presence || "user-#{id}"
  end
end