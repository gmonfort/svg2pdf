require 'tempfile'
require "rsvg2"

module Svg2pdf

  class Svg2pdfError < StandardError; end
  class CairoError < Svg2pdfError; end
  class UnsupportedFormatError < Svg2pdfError; end
  class FileNotFoundError < Svg2pdfError; end
  class InvalidSvgFileError < Svg2pdfError; end

  class << self
    attr_accessor :config
  end

  def self.config
    @config ||= Config.new 
  end

  def self.configure
    yield(config)
  end

  def self.convert_from_file(svg, format, options={})
    options = config.to_hash.merge!(options)
    processor = Processor.new(svg, :from_file, format, options)
    processor.process
  end

  def self.convert_from_data(svg, format, options={})
    options = config.to_hash.merge!(options)
    processor = Processor.new(svg, :from_data, format, options)
    processor.process
  end

  class Config
    attr_accessor :debug, :output_name, :ratio, :use_temporary_dir, :working_dir

    def initialize
      @debug = false
      @output_name = "out"
      @ratio = 1.0
      @use_temporary_dir = false
      @working_dir = "/tmp"
    end

    def to_hash
      Hash[instance_variables.map { |var| [var[1..-1].to_sym, instance_variable_get(var)] }]
    end
  end

  class Processor
    def initialize(input, mode, format, options)
      @svg = input
      @mode = format
      @mode = :jpeg if @mode == :jpg
      setup_options options
      if mode == :from_data
        @handle = RSVG::Handle.new_from_data(@svg)
      else
        @handle = RSVG::Handle.new_from_file(@svg)
      end
    end

    def process
      case @mode
        when :jpeg, :jpg, :png  then render_image
        when :pdf, :ps          then render
        else raise Svg2pdf::UnsupportedFormatError, "Invalid output format: %s" % @mode.to_s
      end
    end

    private

    def render
      setup
      @context = create_context @options[:output_file]
      @context.target.finish
      File.new @options[:output_file]
    end

    def render_image
      setup
      @context = create_context Cairo::FORMAT_ARGB32

      temp = Tempfile.new("svg2")
      @context.target.write_to_png(temp.path)
      @context.target.finish
      @pixbuf = Gdk::Pixbuf.new(temp.path)
      @pixbuf.save(@options[:output_file], @mode.to_s)

      File.new @options[:output_file]
    end

    def setup
      @ratio = @options[:ratio]
      @dim = @handle.dimensions
      @width = @dim.width * @ratio
      @height = @dim.height * @ratio

      surface_class_name = case @mode
        when :jpg, :jpeg, :png  then "ImageSurface"
        when :ps                then "PSSurface"
        when :pdf               then "PDFSurface"
      end
      @surface_class = Cairo.const_get(surface_class_name)
    end

    def create_context(arg)
      surface = @surface_class.new(arg, @width, @height)
      context = Cairo::Context.new(surface)
      context.scale(@ratio, @ratio)
      context.render_rsvg_handle(@handle)
      context
    end

    def setup_options(options)
      # TODO: check working_dir, output_name, etc
      @options = options
      @options[:output_name] += '-' + SecureRandom.hex(16)
      @options[:output_file] = File.join(@options[:working_dir], @options[:output_name] + '.' + @mode.to_s)
    end

    def perform_checks
      check_cairo
      check_svg_file
    end

    def check_svg_file
      raise FileNotFoundError unless File.exists? File.expand_path @svg
      raise InvalidSvgFileError unless File.extname(@svg)[1..-1].downcase =~ /^svg$/
    end

    def check_cairo
      raise CairoError.new("Cairo library not found") if ! RSVG.cairo_available?
    end

  end
end
