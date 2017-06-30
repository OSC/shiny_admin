class BlastJob < ActiveRecord::Base
  include OscMacheteRails::Statusable

  belongs_to :blast

  #FIXME:race condition; sometimes the file has not copied yet
  # Determine if the results are valid
  # def results_valid?
  #   # If the outgraph.json file does not exist, then the search was not successful.
  #   !blast.outgraph.nil?
  # end
end
