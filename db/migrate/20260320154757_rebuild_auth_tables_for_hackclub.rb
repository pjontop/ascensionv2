# frozen_string_literal: true

class RebuildAuthTablesForHackclub < ActiveRecord::Migration[8.1]
  def up
    drop_table :sessions, if_exists: true
    drop_table :users, if_exists: true

    create_table :users do |t|
      t.string :uid
      t.string :name
      t.string :email
      t.string :slack_id
      t.boolean :email_verified
      t.string :verification_status
      t.boolean :ysws_eligible

      t.timestamps
    end

    add_index :users, :uid, unique: true
    add_index :users, :email, unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end
  end

  def down
    drop_table :sessions, if_exists: true
    drop_table :users, if_exists: true

    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :verified, default: false, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end
  end
end
