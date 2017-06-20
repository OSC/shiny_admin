class Blast < ActiveRecord::Base
  has_many :blast_jobs, dependent: :destroy
  has_machete_workflow_of :blast_jobs
  before_create :stage_workflow

  # add accessors: [ :attr1, :attr2 ] etc. when you want to add getters and
  # setters to add new attributes stored in the JSON store
  # don't remove attributes from this list going forward! only deprecate
  store :job_attrs, coder: JSON, accessors: [:account]

  def update_status!
    blast_jobs.to_a.each(&:update_status!)
  end

  # Name that defines the template/target dirs
  def staging_template_name
    "blast"
  end

  # Define tasks to do after staging template directory typically copy over
  # uploaded files here
  # def after_stage(staged_dir)
  #   # CODE HERE
  # end

  # Build an array of Machete jobs that are then submitted to the batch server
  def build_jobs(staged_dir, job_list = [])
    job_list << OSC::Machete::Job.new(script: staged_dir.join("main.sh"), host: "owens")
  end

  # Make copy of workflow
  def copy
    self.dup
  end

  private

  def stage_workflow
    begin
      self.staged_dir = self.stage.to_s
    rescue
      self.errors[:base] << "Cannot stage job because of an error copying the folder, check that you have adequate read permissions to the source folder and that the source folder exists."
      return false
    end
  end
end
