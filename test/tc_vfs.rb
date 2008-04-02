# Author::    Brian Olsen (mailto:bro@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# License::   VirtualFiles is free software distributed under a BSD style license.
#             See LICENSE[file:../LICENSE.html] for permissions.

$root = File.join(File.dirname(__FILE__), '..')
$:.unshift File.join($root, 'lib')

require 'test/unit'
require 'vfs'
require 'vfs/file_path_dav'
require 'vfs/simple_dav_lock'
require 'pp'

class TestVFS < Test::Unit::TestCase
  def test_simple_fs_meta
    fs = VFS::FileSystem.new( VFS::File.new( File.join( $root, 'tmp' ) ) )
    
    fs.define_namespace(:dav, :'DAV:') do
      def hello
        "test"
      end
      property :hello
    end
    
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal [[:'DAV:', :hello]].to_set, fs.lookup('/files').meta.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.dav.properties
    assert_equal "test", fs.lookup('/files').meta.dav.hello
  end
  
  def test_fs_meta
    fs = VFS::FileSystem.new( VFS::File.new( File.join( $root, 'tmp' ) ) )
    fs.define_namespace(:dav, :'DAV:') do
      def hello
        "test"
      end
      property :hello
    end
    fs.define_namespace(:tav, :'TAV:') do
      def hello
        "test2"
      end
      property :hello
    end
    
    assert_equal [[:tav,:'TAV:'],[:dav,:'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal [[:'TAV:', :hello], [:'DAV:', :hello]].to_set, fs.lookup('/files').meta.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.dav.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.tav.properties
    assert_equal "test", fs.lookup('/files').meta.dav.hello
    assert_equal "test2", fs.lookup('/files').meta.tav.hello
  end
  
  def test_fs_include_meta
    fs = VFS::FileSystem.new( VFS::File.new( File.join( $root, 'tmp' ) ) )
    fs.define_namespace(:dav, :'DAV:', VFS::FilePathDAV)
    
    p = %w( lastaccessed creationdate getlastmodified getcontentlength getetag getcontenttype resourcetype )
    t = fs.lookup('/files').meta.dav.properties.to_set
    
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal p.map{|e| [:'DAV:', e.to_sym]}.to_set,fs.lookup('/files').meta.properties
    assert_equal p.map{|e| e.to_sym}.to_set, fs.lookup('/files').meta.dav.properties
  end

  def test_simple_root_meta
    fs = VFS::FileSystem.new
    fs.connect('/', VFS::File.new( File.join( $root, 'tmp' ) ) ) do |m|
      m.define_namespace(:dav, :'DAV:') do
        def hello
          "test"
        end
        property :hello
      end
    end
    
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal [[:'DAV:', :hello]].to_set, fs.lookup('/files').meta.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.dav.properties
    assert_equal "test", fs.lookup('/files').meta.dav.hello
  end
  
  def test_root_meta
    fs = VFS::FileSystem.new
    fs.connect('/', VFS::File.new( File.join( $root, 'tmp' ) ) ) do |m|
      m.define_namespace(:dav, :'DAV:') do
        def hello
          "test"
        end
        property :hello
      end
      m.define_namespace(:tav, :'TAV:') do
        def hello
          "test2"
        end
        property :hello
      end
    end
    
    assert_equal [[:tav, :'TAV:'],[:dav, :'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal [[:'TAV:', :hello], [:'DAV:', :hello]].to_set, fs.lookup('/files').meta.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.dav.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.tav.properties
    assert_equal "test", fs.lookup('/files').meta.dav.hello
    assert_equal "test2", fs.lookup('/files').meta.tav.hello
  end
  
  def test_root_include_meta
    fs = VFS::FileSystem.new
    fs.connect('/', VFS::File.new( File.join( $root, 'tmp' ) ) ) do |m|
      m.define_namespace(:dav, :'DAV:') do
        include VFS::FilePathDAV
      end
    end
    
    p = %w( lastaccessed creationdate getlastmodified getcontentlength getetag getcontenttype resourcetype )
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal p.map{|e| [:'DAV:', e.to_sym]}.to_set,fs.lookup('/files').meta.properties
    assert_equal p.map{|e| e.to_sym}.to_set, fs.lookup('/files').meta.dav.properties
  end
  
  def test_tt
    fs = VFS::FileSystem.new do |map|
      map.connect('/', VFS::File.new(File.join($root, 'tmp' ) ) ) do |root|
        root.define_namespace(:dav, :'DAV:') do
          include VFS::FilePathDAV
        end
      end
      map.define_namespace(:dav, :'DAV:') do
        include VFS::SimpleDAVLock
      end
    end
    
    
    #fs.lookup('/files/tmp').meta.namespace => ????
    #fs.lookup('/tmp').meta.dav.properties => ????
    #fs.lookup('/files/tmp').meta.dav.properties => ????
    
    fs = VFS::FileSystem.new do |map|
      map.root = VFS::File.new(File.join($root, 'tmp' ) )
      map.define_namespace(:dav, :'DAV:') do
        include VFS::FilePathDAV
      end
    end
    fs = VFS::FileSystem.new do |map|
      map.root = VFS::File.new(File.join($root, 'tmp' ) )
      map.connect('/files', VFS::File.new(File.join($root, 'tmp'))) do |n|
        n.restrict :create_dir, :delete_file
      end
#            map.connect '/tags', VFS::Tagging::TagFile.new
      
#            map.dynamic_namespaces = VFS::Tagging::Tags.new
      map.define_namespace(:dav, :'DAV:', [VFS::FilePathDAV,  VFS::SimpleDAVLock])
    end
  end
end
# vim: sts=4:sw=4:ts=4:et