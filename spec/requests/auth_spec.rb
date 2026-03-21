# frozen_string_literal: true

require "rails_helper"

# more tests

RSpec.describe "Auth", type: :request do
  describe "GET /auth/login" do
    it "uses inertia_location for Inertia requests" do
      get login_path, headers: {"X-Inertia" => "true"}

      expect(response).to have_http_status(:conflict)
      expect(response.headers["X-Inertia-Location"]).to be_present
    end

    it "falls back to a normal redirect for non-Inertia requests" do
      get login_path

      expect(response).to redirect_to("/auth/hackclub")
    end
  end
end
