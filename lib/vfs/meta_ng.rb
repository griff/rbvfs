module VFS
  class Meta
    extend InheritableConstants
    
    class << self
      def define_namespace(prefix, uri, &block)
        clazz = self.inheritable_inner_class( prefix, ::VFS::MetaNamespace )
        clazz.class_eval <<-end_eval
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
        
        self.module_eval <<-end_eval
          def #{prefix} 
              return prefix_get( :#{prefix} )
          end
        end_eval
        clazz.class_eval(&block) if block_given?
        clazz
      end
      
      def namespaces
        ns = []
        self.inheritable_constants.each do |t|
          ns_module = self.inheritable_const_get(t)
          if ns_module.respond_to? :namespace
            ns << [ns_module.prefix, ns_module.namespace.to_sym]
          end
        end
        ns.to_set.to_a
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
    end
    
    attr_reader :owner
    def initialize(owner)
      @owner = owner
    end
    
    def namespaces
      self.class.namespaces
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