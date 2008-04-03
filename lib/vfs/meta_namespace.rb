# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

module VFS
  class MetaNamespace
      class << self
        def properties(*ary)
          @properties ||= []
          if ary.size > 0
            ary = ary.flatten.map{|e| e.to_sym}
            @properties.concat(ary)
          end
          @properties.to_set
        end
        
        def property(prop)
          @properties ||= []
          prop = prop.to_sym
          @properties.push(prop)
        end
      end
      
      attr_reader :meta
      
      def initialize( meta )
          @meta = meta
      end
      
      def properties
          self.class.properties
      end
      
      def fetch(name)
        self.__send__(name.to_sym)
      end
      
      def store(name, value)
        self.__send__("#{name}=", value)
      end
      
      def property_reader_missing( name )
          @meta.property_reader_missing( self, name )
      end
      
      def property_writer_missing( name, value )
          @meta.property_writer_missing( self, name, value )
      end
      
      def method_missing( sym, value=nil )
          sym = sym.to_s
          if sym =~ /^(.*)=$/
              return property_writer_missing( $~[1], value )
          else
              return property_reader_missing( sym )
          end
      end
  end
end
