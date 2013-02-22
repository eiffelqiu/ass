# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "ass"
  s.version = "0.0.15"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Eiffel Qiu"]
  s.date = "2013-02-22"
  s.description = "Apple Service Server written with Sinatra and Sequel(Sqlite3)"
  s.email = "eiffelqiu@gmail.com"
  s.executables = ["ass"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    "LICENSE.txt",
    "README.md",
    "VERSION",
    "ass.yml",
    "cron",
    "lib/ass.rb",
    "public/css/bootstrap-responsive.css",
    "public/css/bootstrap-responsive.min.css",
    "public/css/bootstrap.css",
    "public/css/bootstrap.min.css",
    "public/img/glyphicons-halflings-white.png",
    "public/img/glyphicons-halflings.png",
    "public/js/bootstrap.js",
    "public/js/bootstrap.min.js",
    "views/index.erb",
    "views/layout.erb"
  ]
  s.homepage = "http://github.com/eiffelqiu/ass"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "ass"
  s.rubygems_version = "1.8.25"
  s.summary = "Apple Service Server"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sqlite3>, [">= 0"])
      s.add_runtime_dependency(%q<thin>, [">= 0"])
      s.add_runtime_dependency(%q<sinatra>, [">= 0"])
      s.add_runtime_dependency(%q<sequel>, [">= 0"])
      s.add_runtime_dependency(%q<rufus-scheduler>, [">= 0"])
      s.add_runtime_dependency(%q<eventmachine>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 3.2.8"])
      s.add_runtime_dependency(%q<uri-handler>, [">= 0"])
      s.add_development_dependency(%q<shoulda>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>, ["~> 1.1.3"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_runtime_dependency(%q<sqlite3>, [">= 0"])
      s.add_runtime_dependency(%q<thin>, [">= 0"])
      s.add_runtime_dependency(%q<sinatra>, [">= 0"])
      s.add_runtime_dependency(%q<sequel>, [">= 0"])
      s.add_runtime_dependency(%q<rufus-scheduler>, [">= 0"])
      s.add_runtime_dependency(%q<eventmachine>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 3.2.8"])
      s.add_runtime_dependency(%q<uri-handler>, [">= 0"])
    else
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<thin>, [">= 0"])
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<sequel>, [">= 0"])
      s.add_dependency(%q<rufus-scheduler>, [">= 0"])
      s.add_dependency(%q<eventmachine>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 3.2.8"])
      s.add_dependency(%q<uri-handler>, [">= 0"])
      s.add_dependency(%q<shoulda>, [">= 0"])
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<bundler>, ["~> 1.1.3"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<thin>, [">= 0"])
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<sequel>, [">= 0"])
      s.add_dependency(%q<rufus-scheduler>, [">= 0"])
      s.add_dependency(%q<eventmachine>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 3.2.8"])
      s.add_dependency(%q<uri-handler>, [">= 0"])
    end
  else
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<thin>, [">= 0"])
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<sequel>, [">= 0"])
    s.add_dependency(%q<rufus-scheduler>, [">= 0"])
    s.add_dependency(%q<eventmachine>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 3.2.8"])
    s.add_dependency(%q<uri-handler>, [">= 0"])
    s.add_dependency(%q<shoulda>, [">= 0"])
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<bundler>, ["~> 1.1.3"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<thin>, [">= 0"])
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<sequel>, [">= 0"])
    s.add_dependency(%q<rufus-scheduler>, [">= 0"])
    s.add_dependency(%q<eventmachine>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 3.2.8"])
    s.add_dependency(%q<uri-handler>, [">= 0"])
  end
end

