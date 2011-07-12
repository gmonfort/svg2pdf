require 'active_support/secure_random'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Svg2pdf do
  before do
    Svg2pdf.configure do |config|
      config.debug = true
      config.output_name = "test"
    end
  end

  let(:svg) { "spec/assets/gnu.svg" }

  context "Jpeg format" do
    it "creates a jpg image from svg" do
      output = Svg2pdf.convert_from_file(svg, :jpeg)
      check_output_file output, :jpeg
    end

    it "fails for an unsupported format" do
      input = 'spec/assets/chart.svg'
      lambda {
        Svg2pdf.convert_from_file(input, :invalid_format)
      }.should raise_error Svg2pdf::UnsupportedFormatError
    end
  end
  
  context "PNG format" do
    it "creates a png image from svg" do
      output = Svg2pdf.convert_from_file(svg, :png)
      check_output_file output, :png
    end
  end

  context "PDF format" do
    it "creates a pdf file from svg" do
      output = Svg2pdf.convert_from_file(svg, :pdf)
      check_output_file output, :pdf
    end
  end
  context "PS format" do
    it "creates a ps file from svg" do
      output = Svg2pdf.convert_from_file(svg, :ps)
      check_output_file output, :ps
    end
  end

  context "PDF format from SVG in memory" do
    it "creates a pdf file from svg in memory" do
      svg_string = File.open(svg, 'rb') { |f| f.read }
      output = Svg2pdf.convert_from_data(svg_string, :pdf, :output_name => "memory")
      check_output_file output, :pdf
    end
  end

  def check_output_file(file, expected_extension)
    file.should be_kind_of File
    File.extname(file.path).should eql('.'+expected_extension.to_s)
    File.size(file.path).should >= 0
  end
end

