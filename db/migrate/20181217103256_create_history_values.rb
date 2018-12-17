class CreateHistoryValues < ActiveRecord::Migration
  def change
    create_table :history_values do |t|
      t.references :setting, index: true, foreign_key: true
      t.references :user, index: true, foreign_key: true
      t.string :value

      t.timestamps null: false
    end
  end
end
