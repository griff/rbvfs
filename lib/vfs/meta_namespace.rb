#  Created by Brian Olsen on 2007-03-14.
#  Copyright (c) 2007. All rights reserved.
module VFS
  class MetaNamespace
      class << self
        def properties
          @properties ||= []
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
