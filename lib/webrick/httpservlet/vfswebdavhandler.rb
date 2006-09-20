#
# webdavhandler.rb - WEBrick WebDAV handler
#
#  Author: Tatsuki Sugiura <sugi@nemui.org>
#  License: Ruby's
#

require 'time'
require 'fileutils.rb'
require 'rexml/document'
require 'builder'
require 'webrick/httpservlet/vfsfilehandler'
require 'iconv'
require 'vfs'
require 'vfs/fileutils'

module WEBrick
  class HTTPRequest
    # buffer is too small to transport huge files...
    if BUFSIZE < 512 * 1024
      remove_const :BUFSIZE
      BUFSIZE = 512 * 1024
    end
  end

  module Config
    webdavconf = {
      :FileSystemCoding        => "UTF-8",
      :DefaultClientCoding     => "UTF-8",
      :DefaultClientCodingWin  => "CP932",
      :DefaultClientCodingMacx => "UTF-8",
      :DefaultClientCodingUnix => "EUC-JP",
    }
    VFSWebDAVHandler = FileHandler.merge(webdavconf)
  end

  module HTTPStatus
    new_StatusMessage = {
      102, 'Processing',
      207, 'Multi-Status',
      422, 'Unprocessable Entity',
      423, 'Locked',
      424, 'Failed Dependency',
      507, 'Insufficient Storage',
    }
    StatusMessage.each_key {|k| new_StatusMessage.delete(k)}
    StatusMessage.update new_StatusMessage

    new_StatusMessage.each{|code, message|
      var_name = message.gsub(/[ \-]/,'_').upcase
      err_name = message.gsub(/[ \-]/,'')
      
      case code
      when 100...200; parent = Info
      when 200...300; parent = Success
      when 300...400; parent = Redirect
      when 400...500; parent = ClientError
      when 500...600; parent = ServerError
      end

      eval %-
        RC_#{var_name} = #{code}
        class #{err_name} < #{parent}
          def self.code() RC_#{var_name} end
          def self.reason_phrase() StatusMessage[code] end
          def code() self::class::code end
          def reason_phrase() self::class::reason_phrase end
          alias to_i code
        end
      -

      CodeToError[code] = const_get(err_name)
    }
  end # HTTPStatus
end # WEBrick

module WEBrick; module HTTPServlet;
class VFSWebDAVHandler < VFSFileHandler
  class Unsupported < NotImplementedError; end
  class IgnoreProp  < StandardError; end

  class CodeConvFilter
    module Detector
      def dav_ua(req)
        case req["USER-AGENT"]
        when /Microsoft Data Access Internet Publishing/
          {@options[:DefaultClientCodingWin] => 70, "UTF-8" => 30}
        when /^gnome-vfs/
          {"UTF-8" => 90}
        when /^WebDAVFS/
          {@options[:DefaultClientCodingMacx] => 80}
        when /Konqueror/
          {@options[:DefaultClientCodingUnix] => 60, "UTF-8" => 40}
        else
          {}
        end
      end

      def chk_utf8(req)
        begin 
          Iconv.iconv("UTF-8", "UTF-8", req.path, req.path_info)
          {"UTF-8" => 40}
        rescue Iconv::IllegalSequence
          {"UTF-8" => -500}
        end
      end

      def chk_os(req)
        case req["USER-AGENT"]
        when /Microsoft|Windows/i
          {@options[:DefaultClientCodingWin] => 10}
        when /UNIX|X11/i
          {@options[:DefaultClientCodingUnix] => 10}
        when /darwin|MacOSX/
          {"UTF-8" => 20}
        else 
          {}
        end
      end

      def default(req)
        {@options[:DefaultClientCoding] => 20}
      end
    end # Detector
  
    def initialize(options={}, default=Config::VFSWebDAVHandler)
      @options = default.merge(options)
      @detect_meth = [:default, :chk_utf8, :dav_ua, :chk_os]
      @enc_score   = Hash.new(0)
    end
    attr_accessor :detect_meth

    def detect(req)
      self.extend Detector
      detect_meth.each { |meth|
        score = self.__send__ meth, req
        @enc_score.update(score) {|enc, cur, new| cur + new}
      }
      #$DEBUG and $stderr.puts "code detection score ===> #{@enc_score.inspect}"
      platform_codename(@enc_score.keys.sort_by{|k| @enc_score[k] }.last)
    end

    def conv(req, from=nil, to="UTF-8")
      from ||= detect(req)
      #$DEBUG and $stderr.puts "=== CONVERT === #{from} -> #{to}"
      return true if from == to
      req.path_info = Iconv.iconv(to, from, req.path_info).first
      req.instance_variable_set :@path, Iconv.iconv(to, from, req.path).first
      req["destination"].nil? or req.instance_eval {
        @header["destination"][0] = HTTPUtils.escape(
          Iconv.iconv(to, from,
            HTTPUtils.unescape(@header["destination"][0])).first)
      }
      true
    end

    def conv2fscode!(req)
      conv(req, nil, @options[:FileSystemCoding])
    end

    def platform_codename(name)
      case RUBY_PLATFORM
      when /linux/
        name
      when /solaris|sunos/
        {
          "CP932"  => "MS932",
          "EUC-JP" => "eucJP"
        }[name]
      when /aix/
        {
          "CP932"  => "IBM-932",
          "EUC-JP" => "IBM-eucJP"
        }[name]
      else
        name
      end
    end
  end # CodeConvFilter

  def initialize(server, root, options={}, default=Config::VFSWebDAVHandler)
    super
    @cconv = CodeConvFilter.new(@options)
  end

  def service(req, res)
    codeconv_req!(req)
    super
  end

  # TODO:
  #   class 2 protocols; LOCK UNLOCK
  #def do_LOCK(req, res)
  #end
  #def do_UNLOCK(req, res)
  #end

  def do_OPTIONS(req, res)
    @logger.debug "run do_OPTIONS"
    #res["DAV"] = "1,2"
    res["DAV"] = "1"
    res["MS-Author-Via"] = "DAV"
    super
  end

  def do_PROPFIND(req, res)
    map_filename(req, res)
    @logger.debug "propfind requeset depth=#{req['Depth']}"
    depth = (req["Depth"].nil? || req["Depth"] == "infinity") ? -1 : req["Depth"].to_i

    begin
      req_doc = REXML::Document.new req.body
    rescue REXML::ParseException
      raise HTTPStatus::BadRequest
    end
req_doc.write

    raise HTTPStatus::NotFound unless res.filename.exists?
    ns = {""=>"DAV:"}
    req_props = []

    if req.body.nil? || !REXML::XPath.match(req_doc, "/propfind/allprop", ns).empty?
        req_props = :Allprop
    elsif !REXML::XPath.match(req_doc, "/propfind/propname", ns).empty?
        req_props = :Propname
    elsif !REXML::XPath.match(req_doc, "/propfind/prop", ns).empty?
        propelem = REXML::XPath.first(req_doc, "/propfind/prop", ns)
        propelem.each_element { |e|
            req_props << [ e.namespace, e.name ]
        }
    else
      raise HTTPStatus::BadRequest
    end
@logger.debug( req_props )
    ret = get_rec_prop(req, res, res.filename,
                       HTTPUtils.escape(codeconv_str_fscode2utf(req.path)),
                       req_props, *[depth].compact)
                       
@logger.debug(build_multistat(ret).target!)            
    res.body << build_multistat(ret).target!
    res["Content-Type"] = 'text/xml; charset="utf-8"'
    raise HTTPStatus::MultiStatus
  end

  def do_PROPPATCH(req, res)
    map_filename(req, res)
    ret = []
    ns = {""=>"DAV:"}
    begin
      req_doc = REXML::Document.new req.body
    rescue REXML::ParseException
      raise HTTPStatus::BadRequest
    end
    REXML::XPath.each(req_doc, "/propertyupdate/remove/prop/*", ns){|e|
      ps = REXML::Element.new "D:propstat"
      ps.add_element("D:prop").add_element "D:"+e.name
      ps << elem_status(req, res, HTTPStatus::Forbidden)
      ret << ps
    }
    REXML::XPath.each(req_doc, "/propertyupdate/set/prop/*", ns){|e|
      ps = REXML::Element.new "D:propstat"
      ps.add_element("D:prop").add_element "D:"+e.name
      begin
        e.namespace.nil? || e.namespace == "DAV:" or raise Unsupported
        case e.name
        when "getlastmodified"
          res.filename.meta.lastmodified = Time.httpdate(e.text)
        else
          raise Unsupported
        end
        ps << elem_status(req, res, HTTPStatus::OK)
      rescue Errno::EACCES, ArgumentError
        ps << elem_status(req, res, HTTPStatus::Conflict)
      rescue Unsupported
        ps << elem_status(req, res, HTTPStatus::Forbidden)
      rescue
        ps << elem_status(req, res, HTTPStatus::InternalServerError)
      end
      ret << ps
    }
    res.body << build_multistat([[req.request_uri, *ret]]).to_s(0)
    res["Content-Type"] = 'text/xml; charset="utf-8"'
    raise HTTPStatus::MultiStatus
  end

  def do_MKCOL(req, res)
    req.body.nil? or raise HTTPStatus::MethodNotAllowed
    begin
        file = @filesystem.lookup(req.path_info)
        @logger.debug "mkdir #{file}"
        file.mkdir
    rescue Errno::ENOENT, Errno::EACCES
      raise HTTPStatus::Forbidden
    rescue Errno::ENOSPC
      raise HTTPStatus::InsufficientStorage
    rescue Errno::EEXIST
      raise HTTPStatus::Conflict
    end
    raise HTTPStatus::Created
  end

  def do_DELETE(req, res)
    map_filename(req, res)
    begin
      @logger.debug "rm_rf #{res.filename}"
      VFS::Utils.rm_rf( res.filename )
    rescue Errno::EPERM
      raise HTTPStatus::Forbidden
    #rescue
      # FIXME: to return correct error.
      # we needs to stop useing rm_rf and check each deleted entries.
    end
    raise HTTPStatus::NoContent
  end

  def do_PUT(req, res)
    file = @filesystem.lookup(req.path_info)
    if req['range']
      ranges = HTTPUtils::parse_range_header(req['range']) or
        raise HTTPStatus::BadRequest,
          "Unrecognized range-spec: \"#{req['range']}\""
    end

    if !ranges.nil? && ranges.length != 1
      raise HTTPStatus::NotImplemented
    end

    begin
      file.open("w+") {|f|
        if ranges
          # TODO: supports multiple range
          ranges.each{|range|
            first, last = prepare_range(range, filesize)
            first + req.content_length != last and
              raise HTTPStatus::BadRequest
            f.pos = first
            req.body {|buf| f << buf }
          }
        else
          req.body {|buf| f << buf }
        end
      }
    rescue Errno::ENOENT
      raise HTTPStatus::Conflict
    rescue Errno::ENOSPC
      raise HTTPStatus::InsufficientStorage
    end
  end

  def do_COPY(req, res)
    src, dest, depth, exists_p = cp_mv_precheck(req, res)
    @logger.debug "copy #{src} -> #{dest}"
    begin
      if depth.nil? # infinity
        FileUtils.cp_r(src, dest, {:preserve => true}) # todo: fix this
        #src.cp_r( dest )
      elsif depth == 0
        if src.directory?
          meta = src.meta
          #dest.mkdir todo: fix this
          begin
            dest.meta.lastmodified = src.meta.lastmodified
            dest.meta.lastaccessed = src.meta.lastaccessed
          rescue
            # simply ignore
          end
        else
            #src.cp( dest ) todo: fix this
        end
      end
    rescue Errno::ENOENT
      raise HTTPStatus::Conflict
      # FIXME: use multi status(?) and check error URL.
    rescue Errno::ENOSPC
      raise HTTPStatus::InsufficientStorage
    end

    raise exists_p ? HTTPStatus::NoContent : HTTPStatus::Created
  end

  def do_MOVE(req, res)
    src, dest, depth, exists_p = cp_mv_precheck(req, res)
    @logger.debug "rename #{src} -> #{dest}"
    begin
      File.rename(src, dest) # todo: fix this
      #src.rename( dest )
    rescue Errno::ENOENT
      raise HTTPStatus::Conflict
      # FIXME: use multi status(?) and check error URL.
    rescue Errno::ENOSPC
      raise HTTPStatus::InsufficientStorage
    end

    if exists_p
      raise HTTPStatus::NoContent
    else
      raise HTTPStatus::Created
    end
  end


  ######################
  private 

  def get_handler(req)
    return DefaultVFSFileHandler
  end

  def cp_mv_precheck(req, res)
    depth = (req["Depth"].nil? || req["Depth"] == "infinity") ? nil : req["Depth"].to_i
    depth.nil? || depth == 0 or raise HTTPStatus::BadRequest
    @logger.debug "copy/move requested. Deistnation=#{req['Destination']}"
    dest_uri = URI.parse(req["Destination"])
    unless "#{req.host}:#{req.port}" == "#{dest_uri.host}:#{dest_uri.port}"
      raise HTTPStatus::BadGateway
      # TODO: anyone needs to copy other server?
    end
    src  = @filesystem.lookup(req.path_info)
    dest = @filesystem.lookup(resolv_destpath(req))

    src == dest and raise HTTPStatus::Forbidden

    exists_p = false
    if dest.exists?
      exists_p = true
      if req["Overwrite"] == "T"
        @logger.debug "copy/move precheck: Overwrite flug=T, deleteing #{dest}"
        VFS::Utils.rm_rf(dest)
        #FileUtils.rm_rf(dest) # todo: fix this
      else
        raise HTTPStatus::PreconditionFailed
      end
    end
    return *[src, dest, depth, exists_p]
  end

  def codeconv_req!(req)
    @logger.debug "codeconv req obj: orig; path_info='#{req.path_info}', dest='#{req["Destination"]}'"
    begin
      @cconv.conv2fscode!(req)
    rescue Iconv::IllegalSequence
      @logger.warn "code conversion fail! for request object. #{@cconv.detect(req)}->(fscode)"
    end
    @logger.debug "codeconv req obj: ret; path_info='#{req.path_info}', dest='#{req["Destination"]}'"
    true
  end

  def codeconv_str_fscode2utf(str)
    return str if @options[:FileSystemCoding] == "UTF-8"
    @logger.debug "codeconv str fscode2utf: orig='#{str}'"
    begin
      ret = Iconv.iconv("UTF-8", @options[:FileSystemCoding], str).first
    rescue Iconv::IllegalSequence
      @logger.warn "code conversion fail! #{@options[:FileSystemCoding]}->UTF-8 str=#{str.dump}"
      ret = str
    end
    @logger.debug "codeconv str fscode2utf: ret='#{ret}'"
    ret
  end

  def build_multistat(rs)
      m = Builder::XmlMarkup.new
      m.instruct!
      m.multistatus( 'xmlns' => 'DAV:' ) do
          rs.each do |href, *cont|
              m.response do
                  m.href( href )
                  cont.each{ |c| m << c }
              end
          end
      end
      m
  end

    def get_rec_prop(req, res, file, r_uri, props, depth = -1)
        ret_set = []
        ret_set << [r_uri, get_propstat(req, res, file, props)]
        @logger.debug "get prop file='#{file}' depth=#{depth}"
        return ret_set if !(file.directory? && ( depth > 0 || depth < 0 ))
    
        depth -= 1 if depth
        file.entries.each do |d|
            d == ".." || d == "." and next
            
            nextfile = file + d
            if nextfile.directory?
                ret_set += get_rec_prop(req, res, nextfile,
                        HTTPUtils.normalize_path(
                                r_uri+HTTPUtils.escape(
                                codeconv_str_fscode2utf("/#{d}/"))),
                        props, depth)
            else 
                ret_set << [HTTPUtils.normalize_path(
                                    r_uri+HTTPUtils.escape(
                                    codeconv_str_fscode2utf("/#{d}"))),
                             get_propstat(req, res, nextfile, props)
                            ]
            end
        end
        ret_set
    end
  
    def build_status( req, retcodesym )
        "HTTP/#{req.http_version} #{retcodesym.code} #{retcodesym.reason_phrase}"
    end
    
    def tagprop( b, meta, ns, name, &block )
        if ns.to_sym == :'DAV:'
            b.tag!( name, &block )
        else
            b.tag!( "#{meta.namespace(ns)}:#{name}", &block )
        end
    end
  
    def get_propstat( req, res, file, props )
        meta = file.meta
        b = Builder::XmlMarkup.new
        
        namespaces = {}
        meta.namespaces.each { |short, ns|
            ns == :'DAV:' and next
            namespaces["xmlns:#{short}"] = ns
        }
        
        if props == :Propname
            b.propstat namespaces do
                b.prop do
                    meta.all_properties.each { |ns, name|
                        tagprop( b, meta, ns, name )
                    }
                end
                b.status( build_status( req, HTTPStatus::OK ) )
            end
        else
            if props == :Allprop
                props = meta.all_properties
            end
            
            failed_props = []
            b.propstat namespaces do
                b.prop do
                    props.each do |ns, name|
                        begin
                            value = meta[ns].get!( name )
                            tagprop( b, meta, ns, name ) {
                                b << value.to_s
                            }
                        rescue IgnoreProp
                            #simple ignore prop
                        rescue NameError
                            failed_props.push [ ns, name, HTTPStatus::NotFound ]
                        rescue HTTPStatus::Status
                            failed_props.push [ ns, name, errstat ]
#                        rescue
#                            failed_props.push [ ns, name, HTTPStatus::InternalServerError ]
                        end
                    end
                end
                b.status( build_status( req, HTTPStatus::OK ) )
            end
            failed_props.each do |ns, name, status|
                b.propstat do
                    b.prop do
                        b.tag!( "D:#{name}", "xmlns:D" => "#{ns}" )
                    end
                    b.status( build_status( req, status ) )
                end
            end
        end
        
        b.target!
    end

  def get_prop_creationdate(file, st)
    gen_element "D:creationdate", st.creationdate.xmlschema
  end

  def get_prop_getlastmodified(file, st)
    gen_element "D:getlastmodified", st.mtime.httpdate
  end

  def get_prop_getetag(file, st)
    gen_element "D:getetag", st.getetag
  end

  def get_prop_resourcetype(file, st)
    t = gen_element "D:resourcetype"
    file.directory? and t.add_element("D:collection")
    t
  end

  def get_prop_getcontenttype(file, st)
    gen_element("D:getcontenttype",
                file.file? ?
                  HTTPUtils::mime_type(file, @config[:MimeTypes]) :
                  "httpd/unix-directory")
  end

  def get_prop_getcontentlength(file, st)
    file.file? or raise HTTPStatus::NotFound
    gen_element "D:getcontentlength", st.getcontentlength
  end

  def gen_element(elem, text = nil, attrib = {})
    e = REXML::Element.new elem
    text and e.text = text
    attrib.each {|k, v| e.attributes[k] = v }
    e
  end

  def resolv_destpath(req)
    if /^#{Regexp.escape(req.script_name)}/ =~
         HTTPUtils.unescape(URI.parse(req["Destination"]).path)
      return $'
    else
      @logger.error "[BUG] can't resolv destination path. script='#{req.script_name}', path='#{req.path}', dest='#{req["Destination"]}', root='#{@root}'"
      raise HTTPStatus::InternalServerError
    end
  end

end # VFSWebDAVHandler
end; end # HTTPServlet; WEBrick
# vim: sts=4:sw=4:ts=4:et
