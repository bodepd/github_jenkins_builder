require 'torquebox-cache'
require 'yaml'

require 'jenkins_api_client'

class JenkinsBuildProcessor < TorqueBox::Messaging::MessageProcessor

  include TorqueBox::Injectors

  # take in config and generate a jenkins client instance
  def initialize(options = {})
    @server   = options['server']
    @port     = options['port']
    @user     = options['user']
    @password = options['password']
    @client   = JenkinsApi::Client.new(
      :server_ip   => @server,
      :server_port => @port,
      :username    => @user,
      :password    => @password
    )
  end

  def on_message(body)
    puts '!!!!!!!!!jenkins launcher responding to event'

    @build_cache = TorqueBox::Infinispan::Cache.new(
      :name     => 'build_cache'
    )

    last_build = @client.job.get_current_build_number(body['job_name'])

    # create a build based on the message
    @client.job.build(
      body['job_name'],
      {
        'project_name'    => body['project_name'],
        'pull_request'    => body['pull_request'],
        'test_mode'       => body['test_mode'],
        'operatingsystem' => body['operatingsystem'],
        'uuid'            => body['uuid']
  
      }
    )

    current_cached_value = @build_cache.get(body['uuid'])
    @build_cache.replace(
      body['uuid'],
      current_cached_value,
      YAML.load(current_cached_value).merge('state' => 'launched', 'last_build' => last_build).to_yaml
    )

  end

  def on_error(exception)
    # You may optionally override this to interrogate the exception. If you do, 
    # you're responsible for re-raising it to force a retry.
    puts exception
  end

end
