require 'pull_request_tester'
require 'torquebox-cache'
require 'securerandom'
require 'yaml'
#
# this class scans github for pull requests that have been approved
#
class GithubScanner

    include PullRequestTester
    include TorqueBox::Injectors

    # optional, only needed if you pass config options to the job
    def initialize(options = {})

      @project_names   = options["project_names"]
      @admin_users     = options["admin_users"]
      @github_login    = options["github_login"]
      @github_password = options["github_password"]
      @test_message    = options["test_message"] || 'schedule_for_testing'
      @account         = options['account'] || 'puppetlabs'
      @repo_prefix     = options['repo_prefix'] || 'puppetlabs-'
      @job_name        = options['job_name'] || 'test_job'

      puts 'fetching stuff'
      unless @queue = fetch('/queues/launcher')
        # initial the topic queue if it does not yet exist
        puts 'for some reason, we have to create our queue'
        @queue = TorqueBox::Messaging::Queue.new('/queues/launcher')
      end
      puts @queue
      puts '@@@@@@@done fetching stuff'

      @pr_cache   = TorqueBox::Infinispan::Cache.new(
        :name    => 'pull_requests',
        # do not persist while I am testing
        #:persist => '/data/treasure'
      )

      @build_cache = TorqueBox::Infinispan::Cache.new(
        :name     => 'build_cache'
      )
    end

    def run()
      puts 'running git scanner'
      # iterate through all projects as names -> testable pull requests
      testable_pull_requests(
        @project_names,
        @admin_users,
        @github_login,
        @github_password,
        @test_message,
        @account,
        @repo_prefix
      ).each do |k,v|
        # iterate through each pull request for a project
        v.each do |pr_num|
          # create a id per pull request
          id   = "#{k}/#{pr_num}"
          #puts "#{k}=#{v}"
          # check to see if its already in the cache (meaning it has already been processed
          # TODO eventually, I should be checking the state of these, and seeing if I should rerun
          # failures
          unless @pr_cache.get(id)
            puts "putting #{id} into cache"
            # put pull requests onto the queue so we know now to process it again
            @pr_cache.put( id, {'start_time' => Time.now.to_i, 'state' => 'pending' } )
            ['ubuntu'].each do  |os|
              ['puppet_openstack'].each do |test_mode|
                uuid = SecureRandom.uuid
                build_params  = {
                  'job_name'        => @job_name,
                  'project_name'    => k,
                  'pull_request'    => pr_num,
                  'operatingsystem' => os,
                  'test_mode'       => test_mode, 
                  'uuid'            => uuid
                }
                puts "publishing #{build_params.inspect} to queue"
                @queue.publish(build_params)
                @build_cache.put(uuid, build_params.merge('state' => 'triggered').to_yaml)
              end
            end
          else
            #puts "#{id} was already previously processed" 
          end
        end
      end
    end

    def on_error(exception)
      puts exception
    end

end
