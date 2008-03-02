require 'set'
require 'vfs/inheritable_constants'

module VFS
    class MetaNamespace
        attr_reader :meta
        def initialize( meta )
            @meta = meta
        end
        
        def properties
            
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
    
    class Meta
        extend InheritableConstants
        
        class << self
            def namespace( prefix, uri, classname=prefix, &block )
                clazz = inheritable_inner_class( classname, ::VFS::MetaNamespace )
                clazz.class_eval <<-end_eval
                    def self.namespace
                        :'#{uri}'
                    end
                
                    def self.prefix
                        :#{prefix}
                    end
                end_eval
                clazz.class_eval(&block)
                clazz
            end
        end

        def property_reader_missing( ns, name )
            raise NameError, "unknown property reader '#{name}' for namespace '#{ns.namespace}'", caller
        end

        def property_writer_missing( ns, name, value )
            raise NameError, "unknown property writer '#{name}' for namespace '#{ns.namespace}'", caller
        end
        
        
        class Namespace
            class << self
                def property_check( name, method=nil, &block )
                    method = block if block_given?
                    method = lambda(&method) if method
                    self.send :define_method, "check_property_#{name}", method
                    self.send :alias_method, "#{name}?", "check_property_#{name}"
                end
                
                def property_reader( name, method=nil, &block )
                    property_check(name) {true} unless method_defined? :"check_property_#{name}"
                    method = block if block_given?
                    method = lambda(&method) if method
                    self.send :define_method, "read_property_#{name}", method
                    self.send :alias_method, name, "read_property_#{name}"
                end
                
                def property_writer( name, method=nil, &block )
                    property_check(name) {true} unless method_defined? :"check_property_#{name}"
                    method = block if block_given?
                    method = lambda(&method) if method
                    self.send :define_method, "write_property_#{name}", method
                    self.send :alias_method, "#{name}=", "write_property_#{name}"
                end
                
                def property_remover( name, method=nil, &block )
                    property_check(name) {true} unless method_defined? :"check_property_#{name}"
                    method = block if block_given?
                    method = lambda(&method) if method
                    self.send :define_method, "remove_property_#{name}", method
                    self.send :alias_method, "remove_#{name}", "remove_property_#{name}"
                end
                
                def properties_with_checks
                    props = []
                    self.public_instance_methods(false).each { |t|
                        if t =~ /^check_property_.*$/
                            prop = t.match(/^check_property_(.*)$/)[1]
                            props << prop
                        end
                    }
                    props += self.superclass.properties_with_checks if self.superclass.respond_to? :properties_with_checks
                    props
                end
                
                def properties_with_readers
                    props = []
                    self.public_instance_methods(false).each { |t|
                        if t =~ /^read_property_.*$/
                            prop = t.match(/^read_property_(.*)$/)[1]
                            props << prop
                        end
                    }
                    props += self.superclass.properties_with_readers if self.superclass.respond_to? :properties_with_readers
                    props
                end
                
                def properties_with_writers
                    props = []
                    self.public_instance_methods(false).each { |t|
                        if t =~ /^write_property_.*$/
                            prop = t.match(/^write_property_(.*)$/)[1]
                            props << prop
                        end
                    }
                    props += self.superclass.properties_with_writers if self.superclass.respond_to? :properties_with_writers
                    props
                end
                
                def properties_with_removers
                    props = []
                    self.public_instance_methods(false).each { |t|
                        if t =~ /^remove_property_.*$/
                            prop = t.match(/^remove_property_(.*)$/)[1]
                            props << prop
                        end
                    }
                    props += self.superclass.properties_with_removers if self.superclass.respond_to? :properties_with_removers
                    props
                end
                
                def properties
                    properties_with_checks | properties_with_readers | properties_with_writers | properties_with_removers
                end
            end
            
            attr_reader :meta
            def initialize( meta )
                @meta = meta
            end
            
            def properties
                props = []
                properties_with_checks.each { |prop|
                    props << prop if check(prop)
                }
                props | dynamic_properties
            end
            
            def properties_with_checks
                self.class.properties_with_readers
            end
            
            def properties_with_readers
                self.class.properties_with_readers
            end
            
            def properties_with_writers
                self.class.properties_with_writers
            end
            
            def properties_with_removers
                self.class.properties_removers
            end
            
            def check( name )
                method = :"check_property_#{name}"
                if self.respond_to? method 
                    self.__send__( method )
                else
                    self.property_check_missing( name )
                end
            end
            
            def fetch( name )
                method = :"read_property_#{name}"
                self.__send__( method )
#                if self.respond_to? method 
#                else
#                    self.property_reader_missing( name )
#                end
            end
            
            def store( name, value )
                method = :"write_property_#{name}"
                if self.respond_to? method 
                    self.__send__( method, value )
                else
                    self.property_writer_missing( name, value )
                end
            end
            
            def delete( name )
                method = :"remove_property_#{name}"
                if self.respond_to? method 
                    self.__send__( method )
                else
                    self.property_remover_missing( name )
                end
            end
            
            def dynamic_properties
                @meta.dynamic_properties( self.namespace )
            end
            
            def property_check_missing( name )
                @meta.property_check_missing( self.namespace, name )
            end
            
            def property_reader_missing( name )
                @meta.property_reader_missing( self.namespace, name )
            end
            
            def property_writer_missing( name, value )
                @meta.property_writer_missing( self.namespace, name, value )
            end
            
            def property_remover_missing( name )
                @meta.property_remover_missing( self.namespace, name )
            end
            
            def method_missing( sym, value=nil )
                sym = sym.to_s
                if sym =~ /^remove_property_(.*)$/
                    return property_removed_missing( $~[1] )
                elsif sym =~ /^write_property_(.*)$/ 
                    return property_writer_missing( $~[1], value )
                elsif sym =~ /^read_property_(.*)$/
                    return property_reader_missing( $~[1] )
                elsif sym =~ /^check_property_(.*)$/
                    return property_check_missing( $~[1] )
                elsif sym =~ /^remove_(.*)$/
                    return property_remover_missing( $~[1] )
                elsif sym =~ /^(.*)=$/
                    return property_writer_missing( $~[1], value )
                elsif sym =~ /^(.*)\?$/
                    return property_check_missing( $~[1] )
                else
                    return property_reader_missing( sym )
                end
            end
        end

        class Meta
            class << self  # Class methods
                def inheritable_constants
                    ns = self.constants
                    ns |= self.superclass.inheritable_constants if self.superclass.respond_to? :inheritable_constants
                    ns
                end
                
                def inheritable_const_defined?( const )
                    self.const_defined?(const) || 
                        (self.superclass.respond_to?(:inheritable_const_defined?) && 
                            self.superclass.inheritable_const_defined?(const) )
                end
                
                def inheritable_const_get( const )
                    if !self.const_defined?(const) && self.superclass.respond_to?(:inheritable_const_get)
                        return self.superclass.inheritable_const_get( const )
                    end
                    return self.const_get(const)
                end
                
                def namespaces
                    ns = []
                    self.inheritable_constants.each do |t|
                        ns_module = self.inheritable_const_get(t)
                        if ns_module.respond_to? :namespace
                            ns << [t, ns_module.namespace.to_sym]
                        end
                    end
                    ns.to_set.to_a
                end
                
                def namespace_defined?( ns )
                    ns = ns.to_sym
                    namespaces.any { |prefix, n|
                        n == ns
                    }
                end
                
                def namespace_get( ns )
                    ns = ns.to_sym
                    (prefix, n) = namespaces.detect{ |prefix, n|
                        n == ns
                    }
                    return nil unless prefix
                    inheritable_const_get( prefix.to_sym )
                end
                alias :[] :namespace_get

                def define_namespace(n, uri)
                    module_eval %\
                    class #{n} < ::VFS::Meta::Namespace
                        NAMESPACE = :'#{uri}'
                        PREFIX = :#{n}
                        
                        def #{n}.prefix
                            PREFIX
                        end
                        
                        def prefix
                            #{n}::PREFIX
                        end
                        
                        def #{n}.namespace
                            NAMESPACE
                        end
                        def namespace
                            #{n}::NAMESPACE
                        end
                    end
                    def #{n} 
                        return prefix_get( :#{n} )
                    end
                    \
                end

                def inherit_namespace(n)
                    superclass.inherit_namespace(n) if superclass.respond_to?(:inherit_namespace) && !superclass.const_defined?(n)
                    superNamespace = ""
                    if superclass.const_defined? n
                        superNamespace = "< #{superclass}::#{n}"
                    end
                    module_eval %\
                    class #{n}#{superNamespace}
                    end
                    \
                end
                
                def property_check( n, m, method = nil, &block )
                    inherit_namespace n unless const_defined? n
                    modl = const_get(n)
                    modl.property_check( m, method, &block )
                end
                
                def property_reader( n, m, method=nil, &block )
                    inherit_namespace n unless const_defined? n
                    modl = const_get(n)
                    modl.property_reader( m, method, &block )
                end
                
                def property_writer( n, m, method=nil, &block )
                    inherit_namespace n unless const_defined? n
                    modl = const_get(n)
                    modl.property_writer( m, method, &block )
                end
                
                def property_remover( n, m, method=nil, &block )
                    inherit_namespace n unless const_defined? n
                    modl = const_get(n)
                    modl.property_remover( m, method, &block )
                end 

                def property(n, m, args)
                    inherit_namespace n unless const_defined? n
                    modl = const_get(n)
                    if args[:check]
                        modl.property_check( m, args[:check])
                    else
                        modl.property_check( m ) {true}
                    end
                    if args[:read]
                        modl.property_reader( m, args[:read] )
                    end
                    if args[:write]
                        modl.property_writer( m, args[:write] )
                    end
                    if args[:remove]
                        modl.property_remover( m, args[:remove] )
                    end
                end

                def default_namespace
                    reset_default_namespace
                end

                def reset_default_namespace #:nodoc
                    set_default_namespace :'DAV:'
                    :'DAV:'
                end

                # Sets the default namespace to use to the given value, or (if the value
                # is nil or false) to the value returned by the given block.
                #
                # Example:
                #
                #   class Project < ActiveRecord::Base
                #     set_table_name "project"
                #   end
                def set_default_namespace(value = nil, &block)
                    define_attr_method :default_namespace, value, &block
                end
                alias :default_namespace= :set_default_namespace

                private

                # Defines an "attribute" method (like #inheritance_column or
                # #table_name). A new (class) method will be created with the
                # given name. If a value is specified, the new method will
                # return that value (as a string). Otherwise, the given block
                # will be used to compute the value of the method.
                #
                # The original method will be aliased, with the new name being
                # prefixed with "original_". This allows the new method to
                # access the original value.
                #
                # Example:
                #
                #   class A < ActiveRecord::Base
                #     define_attr_method :primary_key, "sysid"
                #     define_attr_method( :inheritance_column ) do
                #       original_inheritance_column + "_id"
                #     end
                #   end
                def define_attr_method(name, value=nil, &block)
                    sing = class << self; self; end
                    sing.send :alias_method, "original_#{name}", name
                    if block_given?
                        sing.send :define_method, name, &block
                    else
                        # use eval instead of a block to work around a memory leak in dev
                        # mode in fcgi
                        sing.class_eval "def #{name}; #{value.to_s.inspect}; end"
                    end
                end
            end
            
            def all_properties
                ret = []
                namespaces.each { |prefix, ns|
                    self[ns].properties.each { |name|
                        ret << [ns, name]
                    }
                }
                ret
            end
        
            def namespaces
                self.class.namespaces
            end
            
            def dynamic_properties( ns )
                []
            end
            
            def property_check_missing( ns, name )
                raise NameError, "unknown property check '#{name}' for namespace '#{ns}'", caller
            end
            
            def property_reader_missing( ns, name )
                raise NameError, "unknown property reader '#{name}' for namespace '#{ns}'", caller
            end

            def property_writer_missing( ns, name, value )
                raise NameError, "unknown property writer '#{name}' for namespace '#{ns}'", caller
            end

            def property_remover_missing( ns, name )
                raise NameError, "unknown property remover '#{name}' for namespace '#{ns}'", caller
            end
            
            def prefix_get( prefix )
                prefix = prefix.to_sym
                nsObj = prefix_cache[prefix]
                return nsObj if nsObj
                
                if prefix_defined?( prefix )
                    nsObj = self.class.inheritable_const_get( prefix ).new( self )
                else
                    nsObj = namespace_missing( prefix, nil )
                end
                namespace_cache[nsObj.namespace] = prefix_cache[nsObj.prefix] = nsObj
            end
            
            def prefix_defined?( prefix )
                self.class.inheritable_const_defined?( prefix )
            end
            
            def namespace_defined?( ns )
                self.class.namespace_defined?( ns )
            end
            
            def namespace_get( ns )
                ns = ns.to_sym
                nsObj = namespace_cache[ns]
                return nsObj if nsObj

                ms = self.class.namespace_get( ns )
                if ms
                    nsObj = ms.new( self )
                else
                    nsObj = namespace_missing( nil, ns )
                end
                namespace_cache[nsObj.namespace] = prefix_cache[nsObj.prefix] = nsObj
            end
            
            def []( ns )
                namespace_get( ns )
            end
            
            def method_missing( sym )
                namespace_missing( sym, nil )
            end
            
            def namespace_missing( prefix, ns )
                raise NameError, "uninitialized namespace #{ns} with prefix #{prefix}", caller
            end
            
            def namespace_cache
                @namespaces = Hash.new unless @namespaces
                @namespaces
            end
            
            def prefix_cache
                @prefixes = Hash.new unless @prefixes
                @prefixes
            end
        end
    end
end
# vim: sts=4:sw=4:ts=4:et