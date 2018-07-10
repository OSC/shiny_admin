require 'ood_support'


class MappingController < ApplicationController
  def index
    @mappings = Mapping
  end


  def new
  end


  def show
    @mapping = Mapping.find params[:id]
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

    errors = add_user_facls(params.symbolize_keys)
    unless errors.nil?
      params[:reason] = errors.to_s
      flash[:danger] = "Unable to add %{user} to FACLs for %{app} because %{reason}." % params.symbolize_keys
      mapping.destroy  # Don't keep an unusable mapping
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
      remove_user_facls(user: mapping.user, app: mapping.app, dataset: mapping.dataset)
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


    # Build FACL for user and domain combination
    # @return [Nfs4Entry]
    def build_facl_entry_for_user(user, domain)
      OodSupport::ACLs::Nfs4Entry.new(
        type: :A,
        flags: [],
        principle: user,
        domain: domain,
        permissions: [:r, :x]
      )
    end


    # Add user FACLs to app and dataset
    # @return errors [Exception]
    def add_user_facls(user:, app:, dataset:)
      absolute_app_path = File.join File.expand_path(
        ENV['APP_PROJECT_SPACE']
      ), app

      # FIXME using the environment for FACL_USER_DOMAIN is expedient, but doesn't feel good
      entry = build_facl_entry_for_user user, ENV['FACL_USER_DOMAIN']

      # Consider doing this in a transactional manner: everything succeeds or it all gets rolled back
      errors = nil
      begin
        acl = OodSupport::ACLs::Nfs4ACL.add_facl(path: absolute_app_path, entry: entry)
        acl = OodSupport::ACLs::Nfs4ACL.add_facl(path: dataset, entry: entry)
      rescue Exception => e
        errors = e
      end

      errors
    end


    def remove_user_facls(user:, app:, dataset:)
      absolute_app_path = File.join File.expand_path(
        ENV['APP_PROJECT_SPACE']
      ), app

      entry = build_facl_entry_for_user user, ENV['FACL_USER_DOMAIN']
      errors = nil

      begin
        OodSupport::ACLs::Nfs4ACL.rem_facl(path: absolute_app_path, entry: entry)
        OodSupport::ACLs::Nfs4ACL.rem_facl(path: dataset, entry: entry)
      rescue Exception => e
        errors = e
      end

      errors
    end
end
