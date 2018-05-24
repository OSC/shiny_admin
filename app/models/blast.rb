class Blast < ActiveRecord::Base
  has_many :blast_jobs, dependent: :destroy
  has_machete_workflow_of :blast_jobs

  validates_presence_of :name

  # add accessors: [ :attr1, :attr2 ] etc. when you want to add getters and
  # setters to add new attributes stored in the JSON store
  # don't remove attributes from this list going forward! only deprecate
  store :job_attrs, coder: JSON, accessors: [:account, :context, :database]

  DB_OPTIONS = %w(blastDB CUDAlign54 CUDAlign135 CUDAlign198)

  def database
    job_attrs[:database] || "blastDB"
  end

  def context
    job_attrs[:context] || :sequence
  end

  def gene?
    context.to_s.to_sym == :gene
  end

  def update_status!
    blast_jobs.to_a.each(&:update_status!)
  end

  def job_name
    Configuration.app_token
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
    Blast.new(name: name, sequence: sequence, context: context)
  end

  def output
    return nil unless staged_dir

    output = Pathname.new(self.staged_dir).join("job.log")
    output.read if output.file?
  end

  def outgraph_file
    return nil unless staged_dir

    Pathname.new(staged_dir).join("outgraph.json")
  end

  # the only way to know if the file is badly formatted is to try to read it
  def graph
    if outgraph_file && outgraph_file.file?
      @graph ||= JSON.load(outgraph_file.read)
    else
      nil
    end
  rescue
    nil
  end

  def jobids
    blast_jobs.map(&:pbsid).join(" ")
  end
end
