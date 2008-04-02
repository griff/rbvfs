# Copyright (c) 2007, Brian Olden
# All rights reserved.
# See LICENSE for permissions.
 
# Rakefile for VirtualFiles

require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/rdoctask'
require './lib/vfs/version'

task :default do
  puts "Please see 'rake --tasks' for an overview of the available tasks."
end

# Packaging tasks: -------------------------------------------------------

PKG_NAME = 'vfs'
PKG_VERSION = VFS::VFS_VERSION
PKG_FILES = FileList[
  "Rakefile", "LICENSE", "README", "TODO", "CHANGES", "setup.rb",
  "doc/README.rdoc",
  "examples/**/*.rb",
  "lib/**/*.rb",
  "test/**/*.rb",
  "test/test-data/**/*",
  "debian/*"
]
PKG_EXTRA_RDOC_FILES = ['doc/README.rdoc', 'LICENSE', 'TODO', 'CHANGES']

spec = Gem::Specification.new do |spec|
  spec.platform = Gem::Platform::RUBY
  spec.summary = 'A very dynamic virtual filesystem API for ruby.'
  spec.name = PKG_NAME
  spec.version = PKG_VERSION
  spec.requirements << 'activesupport >= 1.4.4'
#  spec.requirements << 'Optional: mb-discid >= 0.1.2 (for calculating disc IDs)'
  spec.autorequire = spec.name
  spec.files = PKG_FILES
  spec.description = <<EOF
    RBrainz is a Ruby client library to access the MusicBrainz XML
    web service. RBrainz supports the MusicBrainz XML Metadata Version 1.2,
    including support for labels and extended release events.
    
    RBrainz follows the design of python-musicbrainz2, the reference
    implementation for a MusicBrainz client library. Developers used to
    python-musicbrainz2 should already know most of RBrainz' interface.
    However, RBrainz differs from python-musicbrainz2 wherever it makes
    the library more Ruby like or easier to use.
EOF
  spec.author = ['Brian Olsen']
  spec.email = 'bro@rubyforge.org'
  spec.homepage = 'http://vfs.rubyforge.org'
  spec.rubyforge_project = 'vfs'
  spec.has_rdoc = true
  spec.extra_rdoc_files = PKG_EXTRA_RDOC_FILES
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar_gz= true
end

# Build the VirtualFiles gem and install it"
task :install => [:test] do
  sh %{ruby setup.rb}
end

# Test tasks: ------------------------------------------------------------

desc "Run just the unit tests"
Rake::TestTask.new(:test_units) do |test|
  test.test_files = FileList['test/tc_*.rb']
#  test.libs = ['lib', 'test/lib']
  test.warning = true
end

desc "Run just the functional tests"
Rake::TestTask.new(:test_functional) do |test|
  test.test_files = FileList['test/functional*.rb']
#  test.libs = ['lib', 'test/lib']
  test.warning = true
end

desc "Run the unit and functional tests"
task :test => [:test_units, :test_functional]


# Documentation tasks: ---------------------------------------------------

Rake::RDocTask.new do |rdoc|
  rdoc.title    = "VFS %s" % PKG_VERSION
  rdoc.main     = 'doc/README.rdoc'
  rdoc.rdoc_dir = 'doc/api'
  rdoc.rdoc_files.include('lib/**/*.rb', PKG_EXTRA_RDOC_FILES)
  rdoc.options << '--inline-source' << '--line-numbers' \
               << '--charset=UTF-8' #<< '--diagram'
end

# Other tasks: -----------------------------------------------------------

def egrep(pattern)
  Dir['**/*.rb'].each do |fn|
    count = 0
    open(fn) do |f|
      while line = f.gets
    	count += 1
    	if line =~ pattern
    	  puts "#{fn}:#{count}:#{line}"
    	end
      end
    end
  end
end

desc "Look for TODO and FIXME tags in the code"
task :todo do
  egrep(/#.*(FIXME|TODO)/)
end

desc "Print version information"
task :version do
  puts "%s %s" % [PKG_NAME, PKG_VERSION]
end
