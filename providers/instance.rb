def whyrun_supported?
  true
end

use_inline_resources



action :create do
  if @current_resource.exists
    Chef::Log.info "Tomcat instance #{ @new_resource } already exists - nothing to do."
  else
    converge_by("Create #{ @new_resource }") do
      create_tomcat_instance
    end
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete #{ @new_resource }") do
      delete_tomcat_instance
    end
  else
    Chef::Log.info "Tomcat instance #{ @new_resource } doesnt exist - can't delete."
  end
end

def load_current_resource 
  @current_resource = Chef::Resource::WsiTomcatInstance.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.port(@new_resource.port)
  @current_resource.ssl(@new_resource.ssl)
  @current_resource.tomcat_home(@new_resource.tomcat_home)
  if instance_exists?(@current_resource.name)
    @current_resource.exists     = true
  end
end

def instance_exists?(name)
  Chef::Log.debug "Checking to see if Tomcat instance '#{name}' exists"
  instances_home = ::File.expand_path("instance", current_resource.tomcat_home)
  instance_home = ::File.expand_path(name, instances_home)
  ::File.exists?(instance_home) && ::File.directory?(instance_home)
end

def create_tomcat_instance
  name                  = current_resource.name
  port                  = current_resource.port
  ssl                   = current_resource.ssl
  tomcat_user           = node[:wsi_tomcat][:user][:name]
  tomcat_group          = node[:wsi_tomcat][:group][:name]
  manager_archive_name  = node[:wsi_tomcat][:archive][:manager_name]
  archives_home         = ::File.expand_path("archives", current_resource.tomcat_home)
  manager_archive_path  = ::File.expand_path(manager_archive_name, archives_home)
  instances_home        = ::File.expand_path("instance", current_resource.tomcat_home)
  instance_home         = ::File.expand_path(name, instances_home)
  instance_webapps_path = ::File.expand_path("webapps", instance_home)
  Chef::Log.info "Creating Instance #{name}"
  
  Chef::Log.info "Creating Instance Directory #{instance_home}"
  directory instance_home do
    owner tomcat_user
    group tomcat_group
    action :create
  end
  
  # Create the required directories in the instance directory
  %w{bin conf lib logs temp webapps work}.each do |dir|
    Chef::Log.info "Creating Instance subdirectory #{dir}"
    directory ::File.expand_path(dir, instance_home) do
      owner tomcat_user
      group tomcat_group
      action :create
    end
  end
  
  execute "Create manager application for #{name}" do
    cwd instance_webapps_path
    user tomcat_user
    group tomcat_group
    command "/bin/tar -xvf #{manager_archive_path}"
    not_if ::File.exists?(::File.expand_path("manager", instance_webapps_path))
  end
  
  new_resource.updated_by_last_action(true)
end

def delete_tomcat_instance
  instances_home = ::File.expand_path("instance", current_resource.tomcat_home)
  instance_home  = ::File.expand_path(name, instances_home)
  directory instance_home do
    recursive true
    action :delete
  end
  new_resource.updated_by_last_action(true)
end

