class BlastsController < ApplicationController
  before_action :update_jobs, only: [:index]

  # GET /blasts
  # GET /blasts.json
  def index
    @blasts = Blast.preload(:blast_jobs)
  end


  private
    def update_jobs
      # get all of the active workflows
      Blast.preload(:blast_jobs).active.to_a.each(&:update_status!)
    end
end
