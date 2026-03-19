# frozen_string_literal: true

# lowkirkenuinley idk what this does but it seems to be the only way to get loops working without the API key in test env

require "rails_helper"

RSpec.describe "Rsvps", type: :request do
  include ActiveJob::TestHelper

  describe "POST /rsvps" do
    let(:geolocation_payload) do
      {
        "city_name" => "Cambridge",
        "country_name" => "United States",
        "latitude" => "42.3737",
        "longitude" => "-71.1284",
      }
    end

    before do
      response = instance_double("Net::HTTPResponse", body: geolocation_payload.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(response)

      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "persists an RSVP with submission metadata" do
      expect do
        post rsvps_path, params: { email: "skibidi@example.com" }
      end.to change(Rsvp, :count).by(1)
        .and have_enqueued_job(SyncRsvpToLoopsJob)

      expect(response).to redirect_to(landing_path)

      rsvp = Rsvp.order(:created_at).last
      expect(rsvp.email).to eq("skibidi@example.com")
      expect(rsvp.submitted_at).to be_present
      expect(rsvp.ip_address).to be_present
      expect(rsvp.user_agent).to be_present
      expect(rsvp.geolocation_data).to include("city_name" => "Cambridge")
    end

    it "rejects duplicate email submissions" do
      Rsvp.create!(
        email: "skibidi@example.com",
        submitted_at: Time.current,
        ip_address: "127.0.0.1",
        user_agent: "RSpec",
        geolocation_data: geolocation_payload,
      )

      expect do
        post rsvps_path, params: { email: "skibidi@example.com" }
      end.not_to change(Rsvp, :count)

      expect(enqueued_jobs).to be_empty

      expect(response).to redirect_to(landing_path)
    end
  end
end
