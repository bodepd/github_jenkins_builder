require 'yaml'

class SinatraSession < Sinatra::Base
  # enable via infinispan
  use TorqueBox::Session::ServletStore
  include TorqueBox::Injectors

  get '/queues' do
    output = ''
    TorqueBox::Messaging::Queue.list.each do |queue|
      output << '<br>' << queue.name << ':'
      count = 0
      queue.each {|x| count += 1 }
      output << count.to_s << '<br>'
    end
    output
  end

  get '/build_cache' do
    @build_cache = TorqueBox::Infinispan::Cache.new(
      :name     => 'build_cache'
    )
    @success_cache = TorqueBox::Infinispan::Cache.new(
      :name     => 'success_cache'
    )
    @fail_cache = TorqueBox::Infinispan::Cache.new(
      :name     => 'fail_cache'
    )

    output = ''
    output << '<h2>build cache</h2>' << "\n"
    output << print_cache(@build_cache)
    output << '<h2>builds that completed successfully</h2>'
    output << print_cache(@success_cache)
    output << '<h2>builds that failed</h2>'
    output << print_cache(@fail_cache)
    output
  end

  get '/rebuild' do
    unless @queue = fetch('/queues/launcher')
      # initial the topic queue if it does not yet exist
      puts 'for some reason, we have to create our queue'
      @queue = TorqueBox::Messaging::Queue.new('/queues/launcher')
    end

    @build_cache = TorqueBox::Infinispan::Cache.new(
      :name     => 'build_cache'
    )
    uuid = SecureRandom.uuid
    build_params  = {
      'job_name'        => params['job_name'],
      'project_name'    => params['project_name'],
      'pull_request'    => params['pull_request'],
      'operatingsystem' => params['operatingsystem'],
      'test_mode'       => params['test_mode'],
      'uuid'            => uuid
    }
    @queue.publish(build_params)
    @build_cache.put(uuid, build_params.merge('state' => 'triggered').to_yaml)    
    "publishing #{build_params.inspect} to queue"
  end

  def print_cache(cache)
    output = ''
    if cache.keys.size > 0
      output << '<table border="1">'
      headers = ['uuid', 'job_name', 'project_name', 'pull_request', 'operatingsystem', 'test_mode', 'state', 'last_build', 'build_number']
      output << "\n<tr>\n<th>" <<  headers.join('</th><th>') << "</th>\n</tr>\n"
      cache.keys.each do |key|
        output << "\n<tr>\n<td>"
        body_hash = YAML.load(cache.get(key))
        output << headers.collect {|x| body_hash[x]  }.join('</td><td>')
        inputs = ['job_name', 'project_name', 'pull_request', 'operatingsystem', 'test_mode'].collect do |name|
            "<input type='hidden' name='#{name}' value='#{body_hash[name]}'>"
        end.join('')
        output << "<td><form method='get' action='rebuild'>#{inputs}<input type='submit' value='resubmit test'></form></td>"
        output << "</td>\n<tr>"
      end
      output << '</table>'
    end
    output
  end

end
