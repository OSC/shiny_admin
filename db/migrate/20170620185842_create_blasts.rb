class CreateBlasts < ActiveRecord::Migration
  def change
    create_table :blasts do |t|
      t.string :name
      t.string :sequence
      t.string :staged_dir

      t.timestamps
    end
  end
end
