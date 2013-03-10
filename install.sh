#!/bin/bash
#
# install script
# run this in projects root directory
# it will install torquebox, rvm, and gem dependencies
curl -#L https://get.rvm.io | bash -s stable --ruby
rvm install jruby-1.7.2
rvm use jruby-1.7.2@global
gem install bundler
bundle install
