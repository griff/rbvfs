#!/usr/bin/ruby
require 'rubygems'
require 'webrick'
require 'webrick/httpservlet/vfswebdavhandler'
require 'vfs/dav'
require 'vfs/file_node'

class FileSystem < VFS::FileNode
    meta do
        namespace(:DAV, :'DAV:') do
            include VFS::FilePathDAV
        end
    end
end

fs = VFS::FileSystem.new( VFS::File::Root.new( Dir.pwd ) )

log = WEBrick::Log.new
log.level = WEBrick::Log::DEBUG
serv = WEBrick::HTTPServer.new({:Port => 10080, :Logger => log})
serv.mount("/", WEBrick::HTTPServlet::VFSWebDAVHandler, fs)
trap(:INT){ serv.shutdown }
serv.start
