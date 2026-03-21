# frozen_string_literal: true

require "rails_helper"

# more tests

RSpec.describe SyncRsvpToLoopsJob, type: :job do
  describe "#perform" do
    it "never calls Loops in test environment" do
      rsvp = Rsvp.create!(
        email: "jobspec@gmail.com",
        submitted_at: Time.current,
        ip_address: "127.0.0.1",
        user_agent: "RSpec",
        geolocation_data: {},
      )

      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:loops, :api_key).and_return("fake-key")

      expect(LoopsSdk::Events).not_to receive(:send)

      described_class.perform_now(rsvp.id)
    end
  end
end
