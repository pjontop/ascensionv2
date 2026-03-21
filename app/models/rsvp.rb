# frozen_string_literal: true


class Rsvp < ApplicationRecord
  before_validation :normalize_email
  # instead of validates :email, uniqueness: {case_sensitive: false}, we add a case-insensitive unique index in the database for better performanc
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}, uniqueness: {case_sensitive: false}
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

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
