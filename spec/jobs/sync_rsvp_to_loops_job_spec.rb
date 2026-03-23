# frozen_string_literal: true

require "rails_helper"

RSpec.describe SyncRsvpToLoopsJob, type: :job do
  let(:rsvp) do
    Rsvp.create!(
      email: "jobspec@gmail.com",
      submitted_at: Time.current,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      geolocation_data: {}
    )
  end

  describe "#perform" do
    it "is a no-op in the test environment" do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:loops, :api_key).and_return("fake-key")

      expect(LoopsSdk::Events).not_to receive(:send)

      described_class.perform_now(rsvp.id)
    end

    it "is a no-op when the RSVP record does not exist" do
      allow_any_instance_of(described_class).to receive(:loops_sync_enabled?).and_return(true)
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:loops, :api_key).and_return("fake-key")

      expect(LoopsSdk::Events).not_to receive(:send)

      described_class.perform_now(0) # non-existent ID
    end

    it "is a no-op when the Loops API key is blank" do
      allow_any_instance_of(described_class).to receive(:loops_sync_enabled?).and_return(true)
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:loops, :api_key).and_return(nil)

      expect(LoopsSdk::Events).not_to receive(:send)

      described_class.perform_now(rsvp.id)
    end

    context "when sync is enabled" do
      before do
        allow_any_instance_of(described_class).to receive(:loops_sync_enabled?).and_return(true)
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:loops, :api_key).and_return("fake-key")
        allow(Rails.application.credentials).to receive(:dig).with(:loops, :signup_event_name).and_return("ascension_rsvp")
      end

      it "calls Loops with the correct event and email" do
        expect(LoopsSdk::Events).to receive(:send).with(
          event_name: "ascension_rsvp",
          email: rsvp.email,
          event_properties: hash_including(submittedAt: rsvp.submitted_at.iso8601)
        )

        described_class.perform_now(rsvp.id)
      end

      it "falls back to the default event name when none is configured" do
        allow(Rails.application.credentials).to receive(:dig).with(:loops, :signup_event_name).and_return(nil)

        expect(LoopsSdk::Events).to receive(:send).with(
          hash_including(event_name: "RSVP")
        )

        described_class.perform_now(rsvp.id)
      end

      it "handles a Loops rate limit error without raising" do
        allow(LoopsSdk::Events).to receive(:send).and_raise(LoopsSdk::RateLimitError, "rate limited")

        expect { described_class.perform_now(rsvp.id) }.not_to raise_error
      end

      it "handles a Loops API error without raising" do
        allow(LoopsSdk::Events).to receive(:send).and_raise(LoopsSdk::APIError, "bad request")

        expect { described_class.perform_now(rsvp.id) }.not_to raise_error
      end
    end
  end
end
