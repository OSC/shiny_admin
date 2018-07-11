require 'ood_support'


class MappingsController < ApplicationController
  def index
    @mappings = Mapping.all
  end


  def new
  end


  def show
    @mapping = Mapping.find(params[:id])
  end


  def edit
    @mapping = Mapping.find(params[:id])
  end


  def create
    params = mapping_params
    success = false
    mapping = nil

    begin
      mapping = Mapping.new(params)
      success = mapping.save
    rescue ActiveRecord::RecordNotUnique => e
      user = mapping_params[:user]
      app = mapping_params[:app]
      dataset = mapping_params[:dataset]

      flash[:danger] = "Unable to create duplicate mapping between #{user}, #{app} and #{dataset}"
      redirect_to new_mapping_path
      return
    rescue Exception => e
      flash[:danger] = "An unknown error has occured: " + e.to_s
      redirect_to new_mapping_path
      return
    end

    if not success
      flash[:danger] = 'Creation of new mapping failed.'
      flash[:info] = 'Fields User, App, and Dataset are required and may not be blank.'
      redirect_to new_mapping_path
      return
    end

    flash[:success] = 'Mapping successfully created.'
    redirect_to mapping_index_path
  end


  def destroy
    begin
      id = params[:id]
      mapping = Mapping.find(id)
      mapping.destroy
      flash[:success] = "Successfully deleted mapping."
    rescue Exception => e
      flash[:warning] = 'Unable to delete mapping ' + params[:id] + ' because ' + e.to_s
    end

    redirect_to mapping_index_path
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
