require 'ood_support'


class MappingsController < ApplicationController
  def index
    @directory_permissions_command = Mapping.directory_permissions_command
  end


  # GET /mappings/new
  def new
  end

  # POST /mappings
  def create
    @mapping = Mapping.new(mapping_params)

    if @mapping.save_and_set_facls
      flash[:success] = @mapping.save_message
      redirect_to action: :index
    else
      flash[:warning] = 'Unable to create new mapping. ' + @mapping.format_error_messages
      redirect_to new_mapping_path, locals: params
    end
  end

  # POST /mappings
  def destroy
    mapping = Mapping.get_mapping_for_id(params[:id])

    if mapping.destroy_and_remove_facls()
      flash[:success] = mapping.save_message
      redirect_to action: :index
    else
      flash[:danger] = mapping.save_message
      redirect_to action: :index
    end
  end


  private
    # Whitelist kwarg-style creation of an object using certain keys
    # @return params [Hash]
    def mapping_params
      mapping = params[:mapping]

      if mapping[:dataset] == 'dataset_non_std_location' then
        params[:mapping][:dataset] = mapping[:dataset_non_std_location_value]
      end

      # Remove parameter we don't need at this stage
      params[:mapping].delete(:dataset_non_std_location_value)

      params.require(:mapping).permit(:user, :app, :dataset)
    end
end
