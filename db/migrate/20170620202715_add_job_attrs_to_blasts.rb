class AddJobAttrsToBlasts < ActiveRecord::Migration
  def change
    add_column :blasts, :job_attrs, :string
  end
end
