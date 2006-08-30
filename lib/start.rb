#!/usr/bin/ruby
require 'rubygems'
require 'webrick'
require 'webrick/httpservlet/vfswebdavhandler'

fs = VFS::FileSystem.new( VFS::File::Root.new( Dir.pwd ) )

log = WEBrick::Log.new
log.level = WEBrick::Log::DEBUG
serv = WEBrick::HTTPServer.new({:Port => 10080, :Logger => log})
serv.mount("/", WEBrick::HTTPServlet::VFSWebDAVHandler, fs)
trap(:INT){ serv.shutdown }
serv.start
