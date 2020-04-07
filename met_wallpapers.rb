# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'csv'
require 'fastimage'
require 'fileutils'
require 'json'
require 'open-uri'
require 'optparse'
require 'rmagick'
require 'ruby-progressbar'

class MetArt
  # MetObjects.csv can be downloaded here https://github.com/metmuseum/openaccess
  CSV_PATH = 'MetObjects.csv'
  FOLDER_NAME = 'wallpapers'
  API_URI = 'https://collectionapi.metmuseum.org/public/collection/v1/'
  CLEAR_LINE = "\033[K"
  MOVE_CURSOR_UP = "\033[1A"
  MAX_FILENAME_LENGTH = 100

  attr_accessor :id, :department, :limit, :output_height, :output_width,
                :require_landscape, :require_portrait, :background_color,
                :text_color

  def initialize(params)
    @id = params[:id]
    @department = params[:department]&.downcase
    validate_department if department

    @limit = params[:limit] || Float::MAX
    @output_height = params[:height] || 1080
    @output_width = params[:width] || 1920
    @require_landscape = params[:landscape]
    @require_portrait = params[:portrait]
    @background_color = params[:'background-color'] || 'black'
    @text_color = params[:'text-color'] || 'white'
    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), FOLDER_NAME))
  end

  def fetch
    artworks = if id
                 [{ "Object ID" => id }]
               elsif department
                 data.select { |h| h["Department"].downcase == department }
               else
                 data
               end
    images_downloaded = 0
    print_message("\t--- Downloading ---\n")

    while images_downloaded < limit && !artworks.empty?
      csv_artwork = artworks.delete_at(rand(artworks.size)) # remove random artwork from list
      artwork = artwork_from_id(csv_artwork['Object ID'])
      filename = download_image(artwork)
      next if filename.nil?
      images_downloaded += 1
      format_image(filename, artwork)
      print_message("Success #{images_downloaded}: downloaded '#{filename}'")
      File.delete(filename)
    end
    puralized = 'wallpaper' + (images_downloaded == 1 ? '' : 's')
    print_message("Done. #{images_downloaded} #{puralized} downloaded\n")
  end

  def download_image(artwork)
    image_url = artwork['primaryImage']
    print_error('Failed to find image URL') and return if image_url.nil?
    width, height = FastImage.size(image_url)
    print_error('Could not get image') and return if [width, height].any?(&:nil?)
    print_error('Too Small') and return if width < output_width && height < output_height
    print_error('Not landscape') and return if require_landscape && height > width
    print_error('Not portrait') and return if require_portrait && height < width
    filename = artwork_to_filename(artwork)
    URI.open(image_url) do |image|
      File.open(filename, 'wb') do |file|
        file.puts image.read
      end
    end
    filename
  end

  def format_image(path, artwork)
    image = Magick::ImageList.new(path)
    image.change_geometry!("#{output_width}x#{output_height}") do |cols, rows, img|
     img.resize!(cols, rows)
    end
    title = artwork['title']&.strip
    artist = artwork['artistDisplayName']&.strip
    year = artwork['objectDate']&.strip
    caption = [title, artist, year].map { |s| s unless s&.empty? }.compact.join("\n")
    local_text_color = text_color
    Magick::Draw.new.annotate(image, 0, 0, 20, 15, caption) do
      self.fill = local_text_color
      self.font = 'Palatino-Italic'
      self.gravity = Magick::SouthEastGravity
      self.pointsize = 30
    end
    local_background_color = background_color
    background = Magick::Image.new(output_width, output_height) do
      self.background_color = local_background_color
    end
    image = background.composite(image, Magick::CenterGravity, Magick::OverCompositeOp)
    image.write(output_path(path))
  end

  def data
    @data ||= read_csv(CSV_PATH)
  end

  private

  def artwork_from_id(id)
    JSON.parse(Net::HTTP.get(URI("#{API_URI}objects/#{id}")))
  end

  def read_csv(path)
    validate_csv_present(path)
    print_message("\t--- Loading CSV ---\n")
    row_count = 475_000 # approximate collection count to avoid parsing entire CSV
    progress_bar = ProgressBar.create(total: row_count, length: 80)
    csv_data = []
    CSV.foreach(path, headers: true) do |row|
      progress_bar.increment
      csv_data << row.to_h if row["Is Public Domain"] == "True"
    end
    print_message("#{MOVE_CURSOR_UP}#{CLEAR_LINE}")
    csv_data
  end

  def print_message(message)
    print "\r#{CLEAR_LINE}#{message}"
    $stdout.flush
    true
  end

  def print_error(message)
    print_message("Error: #{message}")
  end

  def exit_with_error(message)
    tabbed_message = message.split("\n").map { |line| "\t#{line}" }.join("\n")
    puts "EXITING:\n#{tabbed_message}"
    exit
  end

  def validate_department
    response = Net::HTTP.get(URI(API_URI + 'departments'))
    valid_departments = JSON.parse(response).fetch('departments').map do |department|
      department['displayName'].downcase
    end
    unless valid_departments.include?(department)
      exit_with_error("Invalid department: '#{department}'")
    end
  end

  def validate_csv_present(path)
    return if File.exist?(path)
    error = <<~MESSAGE
      #{CSV_PATH} not present
      Download #{CSV_PATH} from https://github.com/metmuseum/openaccess and place in the directory of this script
    MESSAGE
    exit_with_error(error)
  end

  def artwork_to_filename(artwork)
    title = artwork['title'] || 'untitled'
    "#{title[0...MAX_FILENAME_LENGTH].downcase.gsub(' ', '_')}.jpg"
  end

  def output_path(filename)
    output = File.join(File.dirname(__FILE__), FOLDER_NAME, filename)
    while File.exist?(output)
      match_data = output.match(/(\d+)\.jpg$/)
      file_number = match_data.nil? ? 0 : match_data.captures.first.to_i + 1
      output.gsub!(/_?\d*\.jpg$/, "_#{file_number}.jpg")
    end
    output
  end
end

params = {}
OptionParser.new do |opts|
  opts.on('--id=NUM', Integer, 'Download a specific work by Object ID')
  opts.on('--width=NUM', Integer, 'Wallpaper output width')
  opts.on('--height=NUM', Integer, 'Wallpaper output height')
  opts.on('-lNUM', '--limit=NUM', Integer, 'Limit the number of wallpapers downloaded')
  opts.on('-dSTRING', '--department=STRING', "Filter to department in this list: #{MetArt::API_URI}departments")
  opts.on('--landscape', 'Restrict to landscape images only')
  opts.on('--portrait', 'Restrict to portrait images only')
  opts.on('--background-color=STRING', "Wallpaper background color string, e.g. '#0c1087', 'pink'")
  opts.on('--text-color=STRING', "Caption text color string, e.g. '#0c1087', 'pink'")
  opts.on('-h', '--help', 'View this menu') do
    puts opts
    exit
  end
end.parse!(into: params)
unless params.empty?
  puts 'Running with options:'
  params.each do |(flag, value)|
    puts "#{flag}: ".rjust(19) + value.to_s
  end
  puts
end

MetArt.new(params).fetch
