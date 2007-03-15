require 'taglib'

#  Created by Brian Olsen on 2007-03-14.
#  Copyright (c) 2007. All rights reserved.
module VFS
    module Taglib
        include MetaNamespaceProxyModule
        PROPERTIES = %w( title artist album comment genre year track length bitrate samplerate channels )

        set_proxy :taglib
        def taglib
            TagLib::File.new(@meta.file_path)
        end
    end
end
