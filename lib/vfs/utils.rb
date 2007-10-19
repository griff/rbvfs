module VFS
  module Utils
    def fs_filepath( parent, name )
        loc_path = parent.fs_filepath
        loc_path += ::File::SEPARATOR unless %r{File::SEPARATOR$} =~ loc_path
        loc_path + name
    end
  
    # Convert a object (path) to a str (if you can ;-)
    def to_path( path )
      path = path.path if path.respond_to? :path
      path = path.to_str if path.respond_to? :to_str
      if /\0/ =~ path
        raise ArgumentError, "pathname contains \\0: #{path.inspect}"
      end
      return path
    end
  
    # Starts with / ?
    def absolute?( path )
        path = VFS.to_path(path)
        path[0] == ?/
    end
  
    # Removes redundant . and resolves .. (pure str magic)
    def cleanpath( path )
      path = to_path(path)
      if !absolute?(path)
        raise ArgumentError, "path is not absolute: #{path.inspect}"
      end
      
      names = []
      path.scan(%r{[^/]+}) do |name|
        next if name == '.'
        if name == '..'
          if !names.empty?
            names.pop
          end
          next
        end
        names << name
      end
      path = '/'
      path << names.join('/')
    end
  
    def expand_path( p, basepath='/' )
      p = to_path(p)
      if !absolute?(p)
        basepath = to_path(basepath)
        basepath = cleanpath( basepath )
        basepath += "/" unless basepath[-1] == ?/
        p = basepath + p
      end
      cleanpath( p )
    end
  
    def path_split( path, basepath = '/')
      path = expand_path(path, basepath)
      # tokenize on / and resolve the name.
      # We need to do it this way because a fileobject is resposibly for all of the leafs below it.
      # Only the fileobject knows how to proceed 
      if block_given?
        path.scan(%r{[^/]+}) {|name| yield name }
      else
        path.scan(%r{[^/]+})
      end
    end
  
    def handler_call(method, delegates, default=nil)
      delegates = Array.new(delegates)
      while handlers.length > 0
        h = handlers.shift
        if h.respond_to? method
          return handler.__send__(method)
        end
      end
      if block_given?
        yield default
      else
        return default
      end
    end
  
    def exists_handler(delegates)
      delegates = Array.new(delegates)
      while delegates.length > 0
        h = delegates.shift
        return h if h.exists?
      end
      return nil
    end
  
    def to_mode(str)
      return str if str.kind_of? Numeric
      str = str.to_str if str.respond_to? :to_str
      case str
        when 'r'
          return File::RDONLY
        when 'r+'
          return File::RDWR
        when 'w'
          return File::TRUNC | File::CREATE | File::WRONLY
        when 'w+'
          return File::TRUNC | File::CREATE | File::RDWR
        when 'a'
          return File::CREATE | File::APPEND | File::WRONLY
        when 'a+'
          return File::CREATE | File::APPEND | File::RDWR
      end
    end
  end
end