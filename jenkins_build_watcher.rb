require 'jenkins_api_client'
require 'pull_request_tester'
require 'torquebox-cache'
require 'yaml'

class JenkinsBuildWatcher

  include TorqueBox::Injectors
  include PullRequestTester

  # take in config and generate a jenkins client instance
  def initialize(options = {})
    @server   = options['server']
    @port     = options['port']
    @user     = options['user']
    @password = options['password'] 
    @github_login    = options['github_login']
    @github_password = options['github_password']
    @account         = options['account']
    @repo_prefix     = options['repo_prefix']
    @client   = JenkinsApi::Client.new(
      :server_ip   => @server,
      :server_port => @port,
      :username    => @user,
      :password    => @password
    )
    @build_cache = TorqueBox::Infinispan::Cache.new(
      :name     => 'build_cache'
    )
  end

  def run
    puts 'launching build watcher'
   
    # access the cache that stores the current state of all builds to watch
    keyset = @build_cache.keys

    puts keyset

    keyset.each do |key|
      body = YAML.load(@build_cache.get(key))

      # check the build queue first if the build was not already started
      if body['state'] == 'launched' || body['state'] == 'queued'
        if check_queue_and_update_cache(body)
          # found build in queue
        elsif check_build_and_update_cache(body)
          # build started
        else
          puts "build #{body['uuid']} was launched, but I cannot find it in the queue or job builds"
        end
      # only check the status of the job's build list it is was already discovered
      elsif body['state'] == 'building'
        if check_build_and_update_cache(body)
        else
          puts "Build was not in building state, I am confused"
        end
      # do nothing is the job build has not been launched yet
      elsif body['state'] == 'triggered'
        puts "Found a build that has not be launched yet, #{key}"
      else
        puts "Unknown build state #{body['state']} for job #{key}"
      end
    end

  end
    
    
  def on_error(exception)
    # You may optionally override this to interrogate the exception. If you do, 
    # you're responsible for re-raising it to force a retry.
    puts exception
    puts exception.backtrace
  end

  private


     # get the console output for a build, and publish it back to the pull request
    def publish_build_results(body, result)
puts 'about to publish results'
      console_output = @client.job.get_console_output(body['job_name'], Integer(body['build_number']))
      publish_results(
        body['project_name'],
        body['pull_request'],
        result,
        console_output['output'].split("\n"),
        { :login => @github_login, :password => @github_password },
        @account,
        @repo_prefix
      )     
    end

    def check_queue_and_update_cache(body)
      if queue_id = get_queue_task_id_from_uuid_param(body['uuid'])
        # try to find the job in the queue
        unless body['state'] == 'queued'
          puts "Updating #{body['uuid']} to queued state"
          @build_cache.replace(
            body['uuid'],
            @build_cache.get(body['uuid']),
            body.merge('state' => 'queued').to_yaml
          )
        else
          puts "Job #{body['uuid']} is still in the queue, we will check its state later"
        end
      else
        # the build is not in the queue
        puts "Job #{body['uuid']} not found on queue"
        return false
      end
      queue_id
    end

    def check_build_and_update_cache(body)
      # check to see if the build is building
      if details = get_build_from_uuid_param(body['job_name'], body['last_build'], body['uuid'])
        puts "found started build: #{details}"
        unless body['state'] == 'building'
          puts "Build was updated to 'building' state from #{body['state']}"
          @build_cache.replace(
            body['uuid'],
            @build_cache.get(body['uuid']),
            body.merge('state' => 'building', 'build_number' => details.first).to_yaml
          ) 
        end
        if result = details[1]['result']
          publish_build_results(body, result)
          @build_cache.remove(body['uuid'])
        else
          puts "Build #{body['uuid']} has not finished, we'll check again later"
        end
      else    
        # maybe I should sleep the remaining duration?
        raise(Exception, "Started build did not exist")
      end
      details
    end

    # get the build id based on a uuid parameter
    def get_queue_task_id_from_uuid_param(uuid)
      @client.queue.list_task_id_with_build_params.each do |id, value|
        if (value['parameters'] and value['parameters']['uuid'] == uuid)
          return id 
        end
      end
      return nil
    end

    def get_build_from_uuid_param(job_name, last_build, uuid)
      current_build = @client.job.get_current_build_number(job_name)
      ((last_build + 1)..current_build).each do |build_num|
        details = get_build_details(job_name, build_num)
        (details['actions'].first['parameters'] || []).each do |param_pair|
          if param_pair['name'] == 'uuid' and param_pair['value'] == uuid
            puts "Found build matching uuid:#{uuid}"
            return [build_num, @client.api_get_request("/job/#{job_name}/#{build_num}")]
          end
        end
      end
      return nil
    end

    def get_build_details(job_name, build_number)
      @client.api_get_request("/job/#{job_name}/#{build_number}")
    end

end
