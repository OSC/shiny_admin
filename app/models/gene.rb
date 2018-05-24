class Gene < Blast
  after_initialize :init_context


  def init_context
    job_attrs[:context] = :gene
  end
end
