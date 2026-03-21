# frozen_string_literal: true

# chatgippity
class AddCaseInsensitiveUniqueIndexToRsvpsEmail < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :rsvps,
              "LOWER(email)",
              unique: true,
              name: "index_rsvps_on_lower_email_unique",
              algorithm: :concurrently
  end

  def down
    remove_index :rsvps, name: "index_rsvps_on_lower_email_unique", algorithm: :concurrently
  end
end
