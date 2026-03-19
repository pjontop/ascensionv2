# frozen_string_literal: true

class CreateRsvps < ActiveRecord::Migration[8.0]
  def change
    create_table :rsvps do |t|
      t.string :email, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :submitted_at, null: false
      t.json :geolocation_data, null: false, default: {}

      t.timestamps
    end

    add_index :rsvps, :email, unique: true
    add_index :rsvps, :submitted_at
  end
end
