# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

module VFS
    module MetaNamespaceModule
        def self.included(base) #:nodoc:
            base.extend(ClassMethods)
=begin comments
            base.class_eval do
              class << self
                include Observable
                alias_method_chain :instantiate, :callbacks
              end

              [:initialize, :create_or_update, :valid?, :create, :update, :destroy].each do |method|
                alias_method_chain method, :callbacks
              end
            end

            CALLBACKS.each do |method|
              base.class_eval <<-"end_eval"
                def self.#{method}(*callbacks, &block)
                  callbacks << block if block_given?
                  write_inheritable_array(#{method.to_sym.inspect}, callbacks)
                end
              end_eval
            end
=end
        end
        
        module ClassMethods #:nodoc:
            def included(base)
              base.properties self::PROPERTIES
            end
            
            def property( name )
              unless const_defined?(:PROPERTIES)
                const_set( :PROPERTIES, [] )
              end
                
              self::PROPERTIES << name.to_sym
            end
        end
    end
end
