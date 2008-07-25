# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

module VFS
  class Properties
    include InheritableConstants
    
    class << self

      def property_namespace(prefix, uri, options={}, &extension)
        options.assert_valid_keys(
          :extend
        )

        clazz = self.get_namespace( prefix, uri )
        if block_given?
          ext = create_extension_module(prefix, extension)
          if options.include?(:extend)
            options[:extend] = Array(options[:extend]).push(ext)
          else
            options[:extend] = ext
          end
        end
        Array(options[:extend]).each{|ext| clazz.send(:include, ext) }

        clazz
      end
      
      def namespaces
        ns = []
        self.inheritable_constants.each do |t|
          ns_module = self.inheritable_const_get(t)
          if ns_module.respond_to?(:namespace) && ns_module.respond_to?(:prefix)
            ns << [ns_module.prefix, ns_module.namespace.to_sym]
          end
        end
        ns.to_set
      end
      
      def properties
        props = []
        self.inheritable_constants.each do |t|
          ns_module = self.inheritable_const_get(t)
          if ns_module.respond_to?(:namespace) && ns_module.respond_to?(:properties)
            props.concat ns_module.properties.map{|p| [ns_module.namespace, p.to_sym]}
          end
        end
        props.to_set
      end
      
      def namespace_defined?( ns )
        ns = ns.to_sym
        namespaces.any { |prefix, n| n == ns }
      end
      
      def namespace_get( ns )
        ns = ns.to_sym
        (prefix, n) = namespaces.detect { |prefix, n| n == ns }
        return nil unless prefix
        inheritable_const_get( prefix.to_sym )
      end
      
      def get_namespace(prefix, uri)
        if self.superclass.respond_to?(:get_namespace)
          clazz = self.superclass.get_namespace(prefix,uri)
        else
          clazz = self.inheritable_inner_class( prefix, ::VFS::MetaNamespace )
          clazz.class_eval(<<-end_eval, __FILE__, __LINE__+1)
            def self.namespace
                :'#{uri}'
            end

            def self.prefix
                :#{prefix}
            end

            def namespace
              self.class.namespace
            end

            def prefix
              self.class.prefix
            end
          end_eval

          self.module_eval(<<-end_eval, __FILE__, __LINE__+1)
            def #{prefix} 
                return prefix_get( :#{prefix} )
            end
          end_eval
        end
        clazz
      end
    end
    
    attr_reader :owner
    def initialize(owner)
      @owner = owner
    end
    
    def namespaces
      self.class.namespaces
    end
    
    def properties
      self.class.properties
    end
    
    def prefix_defined?( prefix )
      self.class.inheritable_const_defined?( prefix )
    end

    def prefix_get( prefix )
      prefix = prefix.to_sym
      ns_obj = prefix_cache[prefix]
      return ns_obj if ns_obj

      return nil unless prefix_defined?( prefix )
      ns_obj = self.class.inheritable_const_get( prefix ).new( self )
      ns_cache[ns_obj.namespace] = prefix_cache[ns_obj.prefix] = ns_obj
    end

    def namespace_defined?(ns)
      self.class.namespace_defined?(ns)
    end
    
    def namespace_get(ns)
      ns = ns.to_sym
      ns_obj = ns_cache[ns]
      return ns_obj if ns_obj
      
      ns_clazz = self.class.namespace_get(ns)
      return nil unless ns_clazz
      
      ns_obj = ns_clazz.new( self )
      ns_cache[ns_obj.namespace] = prefix_cache[ns_obj.prefix] = ns_obj
    end

    def []( ns )
        namespace_get( ns )
    end
    
    def ns_cache
      @ns_cache ||= Hash.new
    end
    
    def prefix_cache
      @prefix_cache ||= Hash.new
    end
  end
end