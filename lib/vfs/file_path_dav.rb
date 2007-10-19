require 'vfs/meta_namespace_module'

#  Created by Brian Olsen on 2007-03-14.
#  Copyright (c) 2007. All rights reserved.
module VFS
  module FilePathDAV
    include MetaNamespaceModule

    PROPERTIES = %w( lastaccessed creationdate getlastmodified getcontentlength getetag getcontenttype resourcetype )

    def lastaccessed
      ::File.atime( self.meta.owner.fs_filepath )
    end
    
    def lastaccessed=( other )
      ::File.utime( other, ::File.mtime( self.meta.owner.fs_filepath ), self.meta.owner.fs_filepath )
      other
    end
    
    def creationdate
      ret = ::File.ctime( self.meta.owner.fs_filepath )
      ret.instance_eval <<-end_eval
        def to_s
          self.xmlschema
        end
      end_eval
      ret
    end
    
    def getlastmodified
      ret = ::File.mtime( self.meta.owner.fs_filepath )
      ret.instance_eval <<-end_eval
        def to_s
          self.httpdate
        end
      end_eval
      ret
    end
    
    def getlastmodified=( other )
      ::File.utime( Time.now, other, self.meta.owner.fs_filepath )
      other
    end
    
    def getcontentlength
      ::File.size( self.meta.owner.fs_filepath )
    end
    
    def getetag
      st = ::File.stat( self.meta.owner.fs_filepath )
      sprintf('%x-%x-%x', st.ino, st.size, st.mtime.to_i )
    end
    
    def getcontenttype
      self.meta.owner.file? ?
        HTTPUtils::mime_type(self.meta.owner) :
        "httpd/unix-directory"
    end
    
    def resourcetype
      if self.meta.owner.directory?
        '<D:collection xmlns:D="DAV:"/>'
      else
        ""
      end
    end
  end
end