# frozen_string_literal: true

class Rsvp < ApplicationRecord
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}, uniqueness: true
  validates :submitted_at, presence: true
  validate :email_must_be_valid_for_delivery

  private

  def email_must_be_valid_for_delivery
    return if email.blank?
    return if EmailAddress.valid?(email)

    errors.add(:email, EmailAddress.error(email) || "is not a valid email address")
  rescue StandardError
    errors.add(:email, "could not be validated")
  end
end
