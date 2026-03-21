# frozen_string_literal: true

require "rails_helper"

# more tests

RSpec.describe Rsvp, type: :model do
  describe "email normalization" do
    it "strips whitespace and downcases before validation" do
      rsvp = described_class.create!(
        email: "  Mixed.Case+Tag@gmail.com ",
        submitted_at: Time.current,
        ip_address: "127.0.0.1",
        user_agent: "RSpec",
        geolocation_data: {},
      )

      expect(rsvp.email).to eq("mixed.case+tag@gmail.com")
    end
  end

  describe "email uniqueness" do
    it "rejects duplicates regardless of case" do
      described_class.create!(
        email: "hello@gmail.com",
        submitted_at: Time.current,
        ip_address: "127.0.0.1",
        user_agent: "RSpec",
        geolocation_data: {},
      )

      duplicate = described_class.new(
        email: "HELLO@gmail.com",
        submitted_at: Time.current,
        ip_address: "127.0.0.2",
        user_agent: "RSpec",
        geolocation_data: {},
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")
    end
  end
end
