# = vfs.rb
#
# Object-Oriented Extendable Virtual Filesystem
#
# Author:: Brian Olsen (mailto:bro@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   VirtualFiles is free software distributed under a BSD style license.
#             See LICENSE[file:../LICENSE.html] for permissions.
#
# For documentation, see module VFS.
#

unless defined?(ActiveSupport)
  begin
    $:.unshift(File.dirname(__FILE__) + "/../../activesupport/lib")  
    require 'active_support'  
  rescue LoadError
    require 'rubygems'
    gem 'activesupport'
    require 'active_support'  
  end
end

require 'set'
require 'vfs/file_system'
require 'vfs/file'
require 'vfs/utils'
require 'vfs/inheritable_constants'
require 'vfs/meta_namespace'
require 'vfs/meta_ng'

#
# == VFS
#
# Extendable Virtual File System
# 
module VFS
    include VFS::Utils
end
# vim: sts=4:sw=4:ts=4:et
