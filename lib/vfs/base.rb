require 'vfs/meta'

module VFS
    # The basic implementation for meta information objects. This class is meant to be extended or included
    # as a mixin and expects there to be implemented a file_path method returning the path to a valid file on
    # the normal file system.
    # See <tt>VFS::File::BaseNode.meta</tt>.
    # See <tt>VFS::File::Meta.file_path</tt>.
    # See <tt>VFS::NopMeta.file_path</tt>.
    class BaseMeta < Meta::Meta
        
        define_namespace :DAV, :'DAV:'
        
        # See <tt>File.atime</tt>.
        property :DAV, :lastaccessed, 
                :set => Proc.new { |other| ::File.utime( other, ::File.mtime( @meta.file_path ), @meta.file_path ); other }, 
                :get=>Proc.new { ::File.atime( @meta.file_path ) }
                
        # See <tt>File.ctime</tt>.
        property_reader( :DAV, :creationdate ){ 
            ret = ::File.ctime( @meta.file_path )
            ret.__send__( :define_method, :to_s ){ self.xmlschema }
            ret
        }
        
        # See <tt>File.mtime</tt>.
        property :DAV, :getlastmodified,
                :set => lambda { |other| ::File.utime( Time.now, other, @meta.file_path ); other },
                :get => lambda {
                    ret = ::File.mtime( @meta.file_path )
                    ret.__send__( :define_method, :to_s ){ self.httpdate }
                    ret
                }
                
        # See <tt>File.size</tt>.
        property_reader( :DAV, :getcontentlength ){ ::File.size( @meta.file_path ) }
        
        property_reader( :DAV, :getetag ){
            st = ::File.stat( @meta.file_path )
            sprintf('%x-%x-%x', st.ino, st.size, st.mtime.to_i )
        }
        
        property_reader( :DAV, :getcontenttype ){
            @meta.owner.file? ?
              HTTPUtils::mime_type(@meta.owner) :
              "httpd/unix-directory"
        }
        
        property_reader( :DAV, :resourcetype ){
            if @meta.owner.directory?
                '<D:collection xmlns:D="DAV:"/>'
            else
                ""
            end
        }
        
        attr_reader :owner
        def initialize( owner )
            @owner = owner
        end
    end
    
    class BaseNode
        include Enumerable
        
        def initialize( name, parent )
            @name = name
            @parent = parent
        end
        
        def fs() @parent.fs() end
            
        def mkdir
            if exists?
                raise Errno::EEXIST
            else
                raise Errno::EACCES
            end
        end

        def open( mode="r" )
            throw Errno::EACCES
        end        
        
        def path( trail_slash=false )
            if @parent
                parentpath = @parent.path
                parentpath += '/' unless %r{/$} =~ parentpath
            else
                parentpath = '/'
            end
            if @name
                parentpath + @name + (trail_slash ? '/' : '')
            else
                parentpath
            end
        end
        alias :to_str :path
        alias :to_s :path

        def +(other)
            other = other.to_str if other.respond_to? :to_str
            @fs.lookup( self.path(true) + other )
        end
        
        def ==( other )
            #other = other.to_str if other.respond_to? :str
            self.path == other
        end
        alias === ==
        alias eq? == 
        
        def <=>(other)
          self.path.tr('/', "\0") <=> other.to_s.tr('/', "\0")
        end

        def hash # :nodoc:
          self.path.hash
        end
        
        def exists?() false end
        
        def file?() false end
            
        def directory?() false end
            
        def each # :yield: filename
            yield "."
            yield ".."
        end
        
        def resolve( name ) NopNode.new( name, self ) end
    end
    
    class NopNode < BaseNode
        def meta() NopMeta.new() if exists? end
            
        def resolve( name ) NopNode.new( name, self ) end
    end
    
    class NopMeta < BaseMeta
        def file_path
            throw Errno::ENOENT
        end
    end
    
    class VirtualMeta < NopMeta
        # See <tt>File.atime</tt>.
        def atime() Time.now end
        
        # See <tt>File.ctime</tt>.
        def ctime() Time.now end
            
        # See <tt>File.mtime</tt>.
        def mtime() Time.now end
            
        # See <tt>File.size</tt>.
        def size() 0 end
    end
        
    # The Root mixin module gives you an easy way to get methods common to all root nodes.
    # This is mainly the assignpath method.
    module Root
        def assignpath( fs, name, parent )
            @fs = fs
            @name = name
            @parent = parent
        end
        
        def fs() @fs end
    end
end

# vim: sts=4:sw=4:ts=4:et