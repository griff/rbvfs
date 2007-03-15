#  Created by Brian Olsen on 2007-03-14.
#  Copyright (c) 2007. All rights reserved.
module VFS
    module FilePathDAV
        include MetaNamespaceModule

        PROPERTIES = %w( lastaccessed creationdate getlastmodified getcontentlength getetag getcontenttype resourcetype )

        def lastaccessed
            ::File.atime( @meta.file_path )
        end
        
        def lastaccessed=( other )
            ::File.utime( other, ::File.mtime( @meta.file_path ), @meta.file_path )
            other
        end
        
        def creationdate
            ret = ::File.ctime( @meta.file_path )
            ret.__send__( :define_method, :to_s ){ self.xmlschema }
            ret
        end
        
        def getlastmodified
            ret = ::File.mtime( @meta.file_path )
            ret.__send__( :define_method, :to_s ){ self.httpdate }
            ret
        end
        
        def getlastmodified=( other )
            ::File.utime( Time.now, other, @meta.file_path )
            other
        end
        
        def getcontentlength
            ::File.size( @meta.file_path )
        end
        
        def getetag
            st = ::File.stat( @meta.file_path )
            sprintf('%x-%x-%x', st.ino, st.size, st.mtime.to_i )
        end
        
        def getcontenttype
            @meta.owner.file? ?
              HTTPUtils::mime_type(@meta.owner) :
              "httpd/unix-directory"
        end
        
        def resourcetype
            if @meta.owner.directory?
                '<D:collection xmlns:D="DAV:"/>'
            else
                ""
            end
        end
    end
end