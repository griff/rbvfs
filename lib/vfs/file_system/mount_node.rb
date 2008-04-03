# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

module VFS
  class FileSystem
    class MountNode
      attr_reader :delegate
      attr_reader :filesystem
      
      def initialize(fs, path, delegate)
        @filesytem = fs
        @path = VFS.path_split(path)
        @delegate = delegate
        @cache = Hash.new
        @real_cache = Hash.new
        @restrictions = [].to_set
        @meta_class = Class.new(fs.meta_class)
        name = ('Mount' + (@path.length > 0 ? '/' : '') + @path.join('/'))
        puts name
        silence_warnings do
          fs.meta_class.const_set( name.camelize, @meta_class )
        end
      end
      
      def ==(other)
        other = VFS.to_path(other)
        self.path == other
      end
      
      def path(trail_slash=false)
        '/' + @path.join('/') + (trail_slash && @path.length > 0? '/' : '')
      end
      
      def lookup(path)
        path = VFS.cleanpath(path)
        ret = @cache[path]
        return ret if ret
        
        path_ar = VFS.path_split(path)
        tt = Array.new(@path)
        
        # Cases:
        #   path == @path
        #   path.contains(@path)
        #   @path.contains(path)
        #   !path.contains(@path) && !@path.contains(path)
        item = tt.shift
        while !item.nil? && item == path_ar.first
          item = tt.shift
          path_ar.shift
        end
        
        if item.nil?
          if path_ar.length > 0
            fileobj = self.resolve(path_ar.shift)
            while path_ar.length > 0
              fileobj = fileobj.resolve(path_ar.shift)
            end
            @cache[path] = fileobj
            @real_cache[path] = fileobj
            return fileobj
          else
            @cache[path] = self
            @real_cache[path] = self
            return self
          end
        end

        if path_ar.length > 0
          return nil
        else
          ret = MountFileFakeItem.new(item, tt.length + 1)
          @cache[path] = ret
          return ret
        end
      end
      
      def real_lookup(path)
        path = VFS.cleanpath(path)
        ret = @real_cache[path]
        return ret if ret
        
        path_ar = VFS.path_split(path)
        tt = Array.new(@path)
        
        # Cases:
        #   path == @path
        #   path.contains(@path)
        #   @path.contains(path)
        #   !path.contains(@path) && !@path.contains(path)
        item = tt.shift
        while !item.nil? && item == path_ar.first
          item = tt.shift
          path_ar.shift
        end
        
        if item.nil?
          if path_ar.length > 0
            fileobj = self.resolve(path_ar.shift)
            while path_ar.length > 0
              fileobj = fileobj.resolve(path_ar.shift)
            end
            @cache[path] = fileobj
            @real_cache[path] = fileobj
            return fileobj
          else
            @cache[path] = self
            @real_cache[path] = self
            return self
          end
        end

        return nil
      end
      
      def entries
        @delegate.entries
      end
      
      def resolve(name)
        MountFileDelegate.new(self, name, @delegate.resolve(name), 1)
      end
      
      def sort_key
        0
      end
      
      def restrict(*operations)
      end
      
      def unrestrict(*operations)
      end
      
      def restrictions
        @restrictions.to_a
      end
      
      def meta_class
        @meta_class
      end
      
      def meta
        self.meta_class.new(@delegate)
      end
      
      def dynamic_namespaces(handler)
        self.meta_class.dynamic_handler = handler
      end
      
      def define_namespace(prefix, ns, options={}, &block)
        self.meta_class.define_namespace(prefix, ns, options, &block)
      end
      
      class MountFileFakeItem
        attr_reader :name, :sort_key
        
        def initialize(name, sort_key)
          @name = name
          @sort_key = sort_key
        end
        
        def delegate
          nil
        end
        
        def entries
          [@name]
        end
        
        def restrictions
          []
        end
        
        def resolve(name)
          nil
        end
      end
      
      class MountFileDelegate
        attr_reader :sort_key, :delegate, :parent, :name
        def initialize(parent, name, delegate, sort_key)
          @parent = parent
          @name = name
          @delegate = delegate
          @sort_key = sort_key
        end
        
        def path(trail_slash=false)
          @parent.path(true) + name + (trail_slash ? '/' : '')
        end
        
        def entries
          @delegate.entries
        end
        
        def restrictions
          @parent.restrictions
        end
        
        def resolve(name)
          MountFileDelegate.new(self, name, @delegate.resolve(name), @sort_key + 1)
        end
        
        def meta_class
          @parent.meta_class
        end
        
        def meta
          self.meta_class.new(@delegate)
        end
      end
    end
  end
end