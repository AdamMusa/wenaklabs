# frozen_string_literal:true

class AddSlugToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :slug, :string
    add_index :users, :slug, unique: true
    User.find_each(&:save)
  end
end
