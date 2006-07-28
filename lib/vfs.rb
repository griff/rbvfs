require 'set'

module VFS
    def VFS.to_path( path )
        path = path.to_str if path.respond_to? :to_str
        if /\0/ =~ path
          raise ArgumentError, "pathname contains \\0: #{path.inspect}"
        end
        return path
    end
    
    def VFS.absolute?( path )
        path = VFS.to_path(path)
        %r{\A/} =~ path
    end
    
    def VFS.cleanpath( path )
        path = VFS.to_path(path)
        if !VFS.absolute?(path)
            raise ArgumentError, "path is not absolute: #{path.inspect}"
        end
        
        names = []
        path.scan(%r{[^/]+}) {|name|
            next if name == '.'
            if name == '..'
                if !names.empty?
                    names.pop
                end
                next
            end
            names << name
        }
        path = '/'
        path << names.join('/')
    end
    
    class OverlayFileObject
        attr_reader :proxy
        #delegate :class, :to => :context
        #delegate :is_a?, :to => :context
        
        def initialize( fs, proxy )
            @fs = fs
            @proxy = proxy
        end
        
        def exists?
            !@fs.entries( @proxy.path ).empty? || @proxy.exists?
        end
        alias :exist? :exists?
        
        def entries
            overlays = @fs.entries( @proxy.path )
            overlays.merge( @proxy.entries ) unless overlays.empty?
            overlays.to_a
        end
        
        def resolve( name )
            wrap( @proxy.resolve( name ) )
        end
            
        def wrap( proxy )
            OverlayFileObject.new( @fs, proxy ) unless proxy.nil?
        end
        
        def method_missing( method, *args, &block )
            @proxy.send( method, *args, &block )
        end
        private :method_missing
    end
    
    class FileSystem
        def initialize( rootfile )
            @mounts = {'/' => OverlayFileObject.new( self, rootfile )}
            @entries = {}
        end
      
        def mount( path, rootfile )
            path = VFS.cleanpath(path)
            @mounts[path] = OverlayFileObject.new( self, rootfile )
            names = []
            path.scan(%r{[^/]+}) {|name|
                entryname = '/' + names.join('/')
                if !@entries[entryname] 
                    @entries[entryname] = [].to_set
                end
                @entries[entryname].add name
                puts "#{entryname} => #{name}"
                names << name
            }
        end
      
        def unmount( path )
            path = path.path if path.respond_to? :path
            path = path.to_str if path.repond_to? :to_str
            entries = @mounts.delete( path )
        end
        
        def entries(path)
            path = VFS.cleanpath(path);
            entry = @entries[path]
            entry ? entry : [].to_set
        end
      
        def lookup( path, basepath="/" )
            path = VFS.to_path(path)
            path = basepath + path unless VFS.absolute?(path)
            if !VFS.absolute?(path)
                basepath = VFS.cleanpath( basepath )
                basepath += "/" unless /\/$/ =~ basepath
                path = basepath + path
            end
            path = VFS.cleanpath( path )
            
            fileobj = @mounts['/']
            path.scan(%r{[^/]+}) {|name|
                fileobj = fileobj.resolve(name)
            }
            return fileobj
        end
      
    end
    
    class FSFileObject
        attr_reader :parent, :name

        def initialize( name, parent, fs_parent=parent )
            @parent = parent
            @fs_parent = parent
            @name = name
            self.taint if @name.tainted? || @parent.tainted?
        end

        def path
            loc_path = (@parent ? @parent.path : "/" )
            loc_path += '/' unless /\/$/ =~ loc_path
            loc_path += @name if @name
            return loc_path 
        end
        
        alias :to_str :path
        alias :to_s :path

        def resolve( name )
            FSFileObject.new( name, self )
        end

        def fs_filepath
            (@fs_parent ? @fs_parent.fs_filepath : "" ) + File::SEPARATOR + @name
        end
    end
    
    class FSFileRoot < FSFileObject
        def initialize( rootpath, parent=nil )
            super(nil, parent, nil)
            @rootpath = VFS.cleanpath( rootpath )
            self.taint if @rootpath.tainted?
        end
       
        def fs_filepath
            @rootpath
        end
    end

    class FSFileObjectMeta
        def initialize( fileObject )
            @file = fileObject
        end

        def atime
            File.atime( @file.fs_filepath )
        end

        def ctime
            File.ctime( @file.fs_filepath )
        end

        def mtime
            File.mtime( @file.fs_filepath )
        end

        def size
            File.size( @file.fs_filepath )
        end

        def size?
            File.size?( @file.fs_filepath )
        end

        def zero?
            File.zero?( @file.fs_filepath )
        end
    end
end


def test( names )
#    return absolute ? '/' : '.' if names.empty?
    path = '/'
    path << names.join('/')
end

module VFS
    class FSFileObject

        def directory?() File.directory?( self.fs_filepath ) end

        def file?() File.file?( fs_filepath ) end

        def exists?() File.exists?( self.fs_filepath ) end
        alias exist? exists?

        def entries() Dir.entries( fs_filepath ) end

        def foreach(&block) Dir.foreach(fs_filepath, &block) end
    end
end


t = VFS::FileSystem.new( VFS::FSFileRoot.new("/Users/griff/Pictures"))
t.mount( '/test/molla', VFS::FSFileRoot.new('/Users/griff/Music') )
t.mount( '/molla/ff', VFS::FSFileRoot.new('/Users/griff/Music') )
puts t.entries('/')
puts t.lookup( "").exists?
puts t.lookup( "").entries
puts "Next"
puts t.lookup("/heelo/../../../test")
puts "Next"
puts t.lookup( "/heelo/../../../test", "/per/ppf")
puts t.lookup( "/heelo/../../../test", "/per/ppf/")
puts t.lookup( "heelo/../../../test", "/per/ppf")
puts t.lookup( "heelo/../../test", "/per/ppf/")
puts t.lookup( "/heelo/../../../test", "per/ppf").fs_filepath

".././Heet/..\\nkll/Hell/../../../".scan(%r{[^/]+}) { |name|
  puts "File: #{name}"
}
