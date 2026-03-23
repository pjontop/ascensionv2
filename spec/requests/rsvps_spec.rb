# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rsvps", type: :request do
  include ActiveJob::TestHelper

  describe "POST /rsvps" do
    let(:headers) { {"User-Agent" => "RSpec"} }
    let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

    let(:geolocation_payload) do
      {
        "city_name" => "Cambridge",
        "country_name" => "United States",
        "latitude" => "42.3737",
        "longitude" => "-71.1284"
      }
    end

    before do
      response = instance_double("Net::HTTPResponse", body: geolocation_payload.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(response)
      allow(Rails).to receive(:cache).and_return(cache_store)
      # cache
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it "persists an RSVP with submission metadata" do
      expect do
        post rsvps_path, params: {email: "skibidi@gmail.com"}, headers: headers
      end.to change(Rsvp, :count).by(1)
        .and have_enqueued_job(SyncRsvpToLoopsJob)

      expect(response).to redirect_to(landing_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)

      rsvp = Rsvp.order(:created_at).last
      expect(rsvp.email).to eq("skibidi@gmail.com")
      expect(rsvp.submitted_at).to be_present
      expect(rsvp.ip_address).to be_present
      expect(rsvp.user_agent).to eq("RSpec")
      expect(rsvp.geolocation_data).to include("city_name" => "Cambridge")
    end

    it "rejects duplicate email submissions" do
      Rsvp.create!(
        email: "skibidi@gmail.com",
        submitted_at: Time.current,
        ip_address: "127.0.0.1",
        user_agent: "RSpec",
        geolocation_data: geolocation_payload,
      )

      expect do
        post rsvps_path, params: {email: "skibidi@gmail.com"}, headers: headers
      end.not_to change(Rsvp, :count)

      expect(enqueued_jobs).to be_empty

      expect(response).to redirect_to(landing_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "returns inertia validation errors for invalid email" do
      expect do
        post rsvps_path, params: {email: "not-an-email"}, headers: headers
      end.not_to change(Rsvp, :count)

      expect(response).to redirect_to(landing_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(inertia).to have_props(
        "errors" => {
          "email" => ["Email is invalid", "Email Invalid Domain Name"]
        }
      )
    end

    it "continues when geolocation lookup times out" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)

      expect do
        post rsvps_path, params: {email: "timeout@gmail.com"}, headers: headers
      end.to change(Rsvp, :count).by(1)

      expect(response).to redirect_to(landing_path)

      rsvp = Rsvp.order(:created_at).last
      expect(rsvp.geolocation_data).to eq({})
    end

    it "caches geolocation data by requester IP" do
      response = instance_double("Net::HTTPResponse", body: geolocation_payload.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      expect(Net::HTTP).to receive(:start).once.and_return(response)

      post rsvps_path, params: {email: "cache-1@gmail.com"}, headers: headers
      post rsvps_path, params: {email: "cache-2@gmail.com"}, headers: headers

      expect(Rsvp.where(email: ["cache-1@gmail.com", "cache-2@gmail.com"]).count).to eq(2)
      expect(Rsvp.find_by!(email: "cache-2@gmail.com").geolocation_data).to include("city_name" => "Cambridge")
    end

    it "does not cache failed geolocation lookups" do
      expect(Net::HTTP).to receive(:start).twice.and_raise(Net::ReadTimeout)

      post rsvps_path, params: {email: "geo-fail-1@gmail.com"}, headers: headers
      post rsvps_path, params: {email: "geo-fail-2@gmail.com"}, headers: headers

      expect(Rsvp.where(email: ["geo-fail-1@gmail.com", "geo-fail-2@gmail.com"]).count).to eq(2)
      expect(Rsvp.find_by!(email: "geo-fail-2@gmail.com").geolocation_data).to eq({})
    end

    it "rate limits excessive submissions from the same IP" do
      RsvpsController::MAX_RSVPS_PER_WINDOW.times do |i|
        post rsvps_path, params: {email: "burst-#{i}@gmail.com"}, headers: headers
        expect(response).to redirect_to(landing_path)
      end

      expect do
        post rsvps_path, params: {email: "blocked@gmail.com"}, headers: headers
      end.not_to change(Rsvp, :count)

      expect(response).to redirect_to(landing_path)
      follow_redirect!
      expect(inertia).to have_flash(alert: "Too many RSVP attempts. Please try again later.")
      expect(inertia).to have_props(
        "errors" => {
          "email" => ["Too many submissions from your network. Please wait and try again."]
        }
      )
    end

    it "continues if cache read/write fails" do
      broken_cache = instance_double("CacheStore")
      allow(Rails).to receive(:cache).and_return(broken_cache)
      allow(broken_cache).to receive(:read).and_raise(StandardError)
      allow(broken_cache).to receive(:write).and_raise(StandardError)
      allow(broken_cache).to receive(:increment).and_raise(StandardError)

      expect do
        post rsvps_path, params: {email: "cache-down@gmail.com"}, headers: headers
      end.to change(Rsvp, :count).by(1)

      expect(response).to redirect_to(landing_path)
    end
  end
end
