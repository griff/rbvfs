#  Created by Brian Olsen on 2007-03-16.
#  Copyright (c) 2007. All rights reserved.
module InheritableConstants
  def camelize(word)
    word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
  end
  
  def inheritable_constants
    consts = self.constants
    consts |= self.superclass.inheritable_constants if self.superclass.respond_to? :inheritable_constants
    consts
  end
    
  def inheritable_const_defined?( const )
    const = camelize(const.to_s)
    self.const_defined?(const) || 
      (self.superclass.respond_to?(:inheritable_const_defined?) && 
          self.superclass.inheritable_const_defined?(const) )
  end
    
  def inheritable_const_get( const )
    const = camelize(const.to_s)
    if !self.const_defined?(const) && self.superclass.respond_to?(:inheritable_const_get)
      return self.superclass.inheritable_const_get( const )
    end
    return self.const_get(const)
  end
  
  def inheritable_inner_class( name, rootclass = Object, &block )
    const = camelize(name.to_s)
    clazz = 
    if !self.const_defined?(const) && self.superclass.respond_to?(:inheritable_const_defined?) && self.superclass.inheritable_const_defined?(const)
      rootclass = self.superclass.inheritable_inner_class(name, rootclass)
      self.const_set( const, Class.new(rootclass))
    elsif !self.const_defined?(const)
      self.const_set( const, Class.new(rootclass))
    else
      self.const_get(const)
    end
    clazz.class_eval(&block) if block_given?
    clazz
  end
end
