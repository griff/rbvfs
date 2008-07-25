# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

module VFS::InheritableConstants
  def self.included(othermod)
    othermod.extend(ClassMethods)
    #othermod.alias_method_chain :const_defined?, :traversal
    #othermod.alias_method_chain :const_set, :traversal
    #othermod.alias_method_chain :const_get, :traversal
  end
  
  module ClassMethods
    def const_defined_with_traversal?(name)
      mod = name.to_s.split('::').inject(self) do |memo,e|
        if memo && memo.const_defined_without_traversal?(e)
          memo = memo.const_get_without_traversal(e)
        else
          nil
        end
      end
      !mod.nil?
    end
    
    def const_get_with_traversal(name)
      name.to_s.split('::').inject(self) do |memo,e|
        memo = memo.const_get_without_traversal(e)
      end
    end
    
    def const_set_with_traversal(name, value)
      names = name.to_s.split('::')
      last_name = names.pop
      mod = names.inject(self) do |memo,e|
        memo = memo.const_get_without_traversal(e)
      end
      
    end
    
    def create_extension_module(extension_id, extension)
      extension_module_name = "#{self.to_s}::#{extension_id.to_s.camelize}ExtensionModule"

      puts "(#{extension_module_name})"
      puts Object.const_defined?(extension_module_name)
      
      silence_warnings do
        mod = Module.new()
        mod.send :include, ::VFS::MetaNamespaceModule
        mod.module_eval(&extension)
        Object.const_set(extension_module_name, mod)
      end
      
      extension_module_name.constantize
    end

#    def camelize(word)
#      word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
#    end
  
    def inheritable_constants
      consts = self.constants
      consts |= self.superclass.inheritable_constants if self.superclass.respond_to? :inheritable_constants
      consts
    end
    
    def inheritable_const_defined?( const )
      const = const.to_s.camelize
      self.const_defined?(const) || 
        (self.superclass.respond_to?(:inheritable_const_defined?) && 
            self.superclass.inheritable_const_defined?(const) )
    end
    
    def inheritable_const_get( const )
      const = const.to_s.camelize
      if !self.const_defined?(const) && self.superclass.respond_to?(:inheritable_const_get)
        return self.superclass.inheritable_const_get( const )
      end
      return self.const_get(const)
    end
  
    def inheritable_inner_class( name, rootclass = Object, &block )
      const = name.to_s.camelize
      clazz = 
      if !self.const_defined?(const) && self.superclass.respond_to?(:inheritable_const_defined?) && self.superclass.inheritable_const_defined?(const)
        rootclass = self.superclass.inheritable_inner_class(name, rootclass)
        self.const_set(const, Class.new(rootclass))
      elsif !self.const_defined?(const)
        self.const_set(const, Class.new(rootclass))
      else
        self.const_get(const)
      end
      clazz.class_eval(&block) if block_given?
      clazz
    end
  end
end
