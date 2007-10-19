require 'vfs/meta_namespace_module'

#  Created by Brian Olsen on 2007-03-14.
#  Copyright (c) 2007. All rights reserved.
module VFS
  module SimpleDAVLock
    include MetaNamespaceModule

    PROPERTIES = %w( test )
    
    def test
    end
  end
end
