# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

require 'singleton'

module VFS
  class FileSystem
    include Singleton

    def initialize()
      @mounts = Array.new
      @cache = Hash.new
      @cache['/'] = FileNode.new(self)
    end
    
    def meta_class
      VFS::Meta
    end
    
    def root=( new_root )
      if new_root
        connect('/', new_root)
      else
        disconnect('/')
      end
    end

    def connect( path, root )
      path = VFS.cleanpath( path )
      idx = @mounts.index(path)
      mount_node = MountNode.new(self,path,root)
      if idx
        @mounts[idx] = mount_node
      else
        @mounts << mount_node
      end
      if block_given?
        yield mount_node
      else
        return mount_node
      end
    end
    
    def disconnect(path)
      path = VFS.cleanpath( path )
      idx = @mounts.index(path)
      @mounts.delete_at(idx) if idx
    end
    
    def mounts(path)
      path = VFS.cleanpath(path)
      @mounts.map{|n| n.lookup(path)}.compact
    end
    
    def real_mounts(path)
      path = VFS.cleanpath(path)
      @mounts.map{|n| n.real_lookup(path)}.compact
    end
    
    def lookup(path, basepath='/')
      path = VFS.expand_path(path, basepath)
      
      fileobj = @cache[path]
      ca = VFS.path_split(path, basepath)
      ra = []
      while fileobj.nil?
        ra.unshift ca.pop
        path = '/' + ca.join('/')
        fileobj = @cache[path]
      end
      
      ra.each do |name|
        fileobj = fileobj.resolve(name)
        @cache[fileobj.path] = fileobj
      end
      if block_given?
        yield fileobj
      else
        return fileobj
      end
    end
    alias :[] :lookup
    
    def define_namespace(prefix, ns, extends={}, &block)
      self.meta_class.define_namespace(prefix, ns, extends, &block)
    end
  end
end

require 'vfs/file_system/file_node'
require 'vfs/file_system/mount_node'
