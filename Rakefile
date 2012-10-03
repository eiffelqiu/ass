# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "ass"
  gem.homepage = "http://github.com/eiffelqiu/ass"
  gem.license = "MIT"
  gem.summary = %Q{Apple Service Server}
  gem.description = %Q{Apple Service Server written with Sinatra and Sequel(Sqlite3)}
  gem.email = "eiffelqiu@gmail.com"
  gem.authors = ["Eiffel Qiu"]
  gem.executables = ['ass']
  gem.files = %w(cron LICENSE.txt README.md ass.yml VERSION) + Dir.glob('lib/**/*') + Dir.glob('views/**/*')  + Dir.glob('public/**/*')
  # dependencies defined in Gemfile
  gem.add_dependency 'sqlite3'
  gem.add_dependency 'thin'
  gem.add_dependency 'sinatra'
  gem.add_dependency 'sequel'
  gem.add_dependency 'rufus-scheduler'
  gem.add_dependency 'eventmachine'
  gem.add_dependency 'activesupport', '>= 3.2.8'  
  gem.add_dependency 'uri-handler' 
  
  gem.rubyforge_project = 'ass'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ass #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
