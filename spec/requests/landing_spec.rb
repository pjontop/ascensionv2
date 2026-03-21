# frozen_string_literal: true

# more tests 

require "rails_helper"

RSpec.describe "Landing", type: :request do
  describe "GET /landing" do
    it "renders the landing component with anonymous auth shared props" do
      get landing_path

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component("landing/index")
      expect(inertia).to have_props(
        "auth" => {
          "user" => nil,
          "session" => nil,
        }
      )
    end
  end
end
