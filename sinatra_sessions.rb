@foo = 0
require 'yaml'

class SinatraSession < Sinatra::Base
  # enable via infinispan
  use TorqueBox::Session::ServletStore
  include TorqueBox::Injectors

  get '/foo' do
    #data = JSON.parse(request.body.string)
    #puts data.inspect
    #topic = fetch('/topics/launcher')
    #topic = TorqueBox::Messaging::Topic.new('/topics/launcher')
    #@foo = @foo + 1
    #topic.publish(@foo)
    #session[:message] = topic.receive
    #redirect to "bar"
  end

  get '/bar' do
    session[:message]
  end

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
    output = ''
    @build_cache.keys.each do |key|
      output << '<br>' << key << '<br>'
      body = @build_cache.get(key)
      output << '    ' << body.inspect
    end
    output
  end

  get '/clear_queues' do
    TorqueBox::Messaging::Queue.list.each do |queue|
      queue.clear
    end
  end

end
