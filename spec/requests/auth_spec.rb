# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth", type: :request do
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "hackclub",
      uid: "hc-user-123",
      info: {name: "Alice Hacker", email: "alice@hackclub.com"},
      extra: {
        raw_info: {
          slack_id: "U12345ABC",
          email_verified: true,
          verification_status: "verified",
          ysws_eligible: true
        }
      }
    )
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  describe "GET /auth/login" do
    it "returns Inertia-Location header for Inertia requests" do
      get login_path, headers: {"X-Inertia" => "true"}

      expect(response).to have_http_status(:conflict)
      expect(response.headers["X-Inertia-Location"]).to eq(login_url)
    end

    it "renders a POST trampoline page for non-Inertia requests" do
      get login_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('method="post"')
      expect(response.body).to include('action="/auth/hackclub"')
    end

    it "includes a CSP nonce on the inline script" do
      get login_path

      nonce_pattern = /nonce="[A-Za-z0-9+\/]+=*"/
      expect(response.body).to match(nonce_pattern)
    end
  end

  describe "OmniAuth callback (POST /auth/hackclub)" do
    it "creates a new user and signs them in" do
      expect do
        post "/auth/hackclub"
        follow_redirect! # → /auth/hackclub/callback which creates the user
      end.to change(User, :count).by(1)

      expect(response).to redirect_to(landing_path)

      user = User.find_by!(uid: "hc-user-123")
      expect(user.name).to eq("Alice Hacker")
      expect(user.email).to eq("alice@hackclub.com")
      expect(user.slack_id).to eq("U12345ABC")
      expect(user.email_verified).to be(true)
      expect(user.verification_status).to eq("verified")
      expect(user.ysws_eligible).to be(true)
    end

    it "updates an existing user's attributes on re-login" do
      User.create!(uid: "hc-user-123", name: "Old Name", email: "old@hackclub.com")

      expect { post "/auth/hackclub" }.not_to change(User, :count)

      follow_redirect! # → callback
      expect(response).to redirect_to(landing_path)

      user = User.find_by!(uid: "hc-user-123")
      expect(user.name).to eq("Alice Hacker")
      expect(user.email).to eq("alice@hackclub.com")
    end

    it "sets the session user_id after successful login" do
      post "/auth/hackclub"
      follow_redirect!
      follow_redirect! # → landing

      expect(session[:user_id]).to eq(User.find_by!(uid: "hc-user-123").id)
    end
  end

  describe "GET /auth/logout" do
    it "clears the session and redirects to root" do
      user = User.create!(uid: "hc-user-123", name: "Alice", email: "alice@hackclub.com")
      post "/auth/hackclub"
      follow_redirect! # → callback, sets session

      get logout_path

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(session[:user_id]).to be_nil
    end

    it "works even when no user is logged in" do
      get logout_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /auth/failure" do
    it "redirects to root with an alert" do
      get "/auth/failure", params: {message: "access_denied"}

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "includes the failure message in the alert" do
      get "/auth/failure", params: {message: "invalid_credentials"}

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to include("invalid_credentials")
    end
  end
end
