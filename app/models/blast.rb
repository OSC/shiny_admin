class Blast < ActiveRecord::Base
  has_many :blast_jobs, dependent: :destroy
  has_machete_workflow_of :blast_jobs

  # add accessors: [ :attr1, :attr2 ] etc. when you want to add getters and
  # setters to add new attributes stored in the JSON store
  # don't remove attributes from this list going forward! only deprecate
  store :job_attrs, coder: JSON, accessors: [:account]

  def update_status!
    blast_jobs.to_a.each(&:update_status!)
  end

  # get all blasts that have active jobs
  scope :active, -> { joins(:blast_jobs).merge(BlastJob.active) }

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
    Blast.new(name: name, sequence: sequence)
  end

  def output
    output = Dir.glob("#{self.staged_dir}/gfam_scores.o*").first
    File.read output if output
  end

  def outgraph
    output = Dir.glob("#{self.staged_dir}/outgraph.json").first
    File.read output if output
  end
end
