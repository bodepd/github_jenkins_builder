#!/bin/bash
set -e
#gem install torquebox-backstage
#export TORQUEBOX_HOME=/home/danbode/.rvm/gems/jruby-1.7.3@global/gems/torquebox-server-2.3.0-java
#backstage deploy
export RUBYLIB=`pwd`
bundle exec torquebox undeploy
bundle exec torquebox deploy
bundle exec torquebox run -p 8282
