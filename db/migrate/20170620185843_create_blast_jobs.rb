class CreateBlastJobs < ActiveRecord::Migration
  def change
    create_table :blast_jobs do |t|
      t.references :blast, index: true, foreign_key: true
      t.string :status
      t.text :job_cache

      t.timestamps
    end
  end
end
