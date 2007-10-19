# = vfs.rb
#
# Object-Oriented Extendable Virtual Filesystem
#
# Author:: Brian Olsen <griff@maven-group.org>
# Documentation:: Author and Christian Theil Have
#
# For documentation, see module VFS.
#
require 'set'
require 'vfs/file_system'
require 'vfs/file'
require 'vfs/utils'
require 'vfs/inheritable_constants'
require 'vfs/meta_namespace'
require 'vfs/meta_ng'

#
# == VFS
#
# Extendable Virtual File System
# 
module VFS
    extend Utils
end
# vim: sts=4:sw=4:ts=4:et
