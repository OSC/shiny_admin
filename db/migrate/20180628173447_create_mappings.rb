class CreateMappings < ActiveRecord::Migration
  def change
    create_table :mappings do |t|
      t.string :user, null: false
      t.string :app, null: false
      t.string :dataset, null: false
      t.text :extensions

      t.timestamps null: false
    end

    add_index :mappings, [:user, :app, :dataset], :unique => true
  end
end
