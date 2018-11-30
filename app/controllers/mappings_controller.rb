require 'ood_support'


class MappingsController < ApplicationController
  # GET /mappings
  def index
    @directory_permissions_command = Mapping.directory_permissions_command
  end

  # PUT /mappings/fix_permissions
  def fix_permissions
    @directory_permissions_command = Mapping.directory_permissions_command
    @permission_changes = Mapping.fix_permissions

    render :index
  end


  # GET /mappings/new
  def new
  end

  # POST /mappings
  def create
    @mapping = Mapping.new(mapping_params)

    if @mapping.save_and_set_facls
      flash[:success] = 'Mapping successfully created.'
      redirect_to action: :index
    else
      flash.now[:warning] = 'Unable to create new mapping. ' + @mapping.errors.full_messages.join(' ')
      render :new
    end
  end

  # POST /mappings
  def destroy
    @mapping = Mapping.find(params[:id])
    if @mapping.destroy_and_remove_facls()
      flash[:success] = 'Mapping successfully removed.'
      redirect_to action: :index
    else
      flash[:danger] = 'Unable to remove mapping. ' + @mapping.errors.full_messages.join(' ')
      redirect_to action: :index
    end
  rescue ActiveRecord::RecordNotFound
    flash[:warning] = "Unable to find mapping #{params[:id]} to remove it."
    redirect_to action: :index
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
