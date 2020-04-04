class MetArt
  require 'fileutils'
  require 'csv'
  require 'fastimage'
  require 'open-uri'
  require 'optparse'
  require 'rmagick'
  require 'json'
  require 'ruby-progressbar'

  FOLDER_NAME = 'wallpapers'.freeze
  API_URI = 'https://collectionapi.metmuseum.org/public/collection/v1/'.freeze

  attr_accessor :department, :limit, :output_height, :output_width,
                :require_landscape, :require_portrait, :background_color,
                :text_color

  def initialize(params)
    @department = params[:department]&.downcase
    validate_department

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
    artworks = if department.nil?
      data
    else
      data.select { |h| h["Department"].downcase == department }
    end
    images_downloaded = 0

    while images_downloaded < limit && !artworks.empty?
      artwork = artworks.delete_at(rand(artworks.size)) # remove random artwork from list
      path = download_image(artwork)
      unless path.nil?
        images_downloaded += 1
        format_image(path, artwork)
        File.delete(path)
      end
    end
    puts "Done. #{images_downloaded} images downloaded"
  end

  def download_image(artwork)
    response = Net::HTTP.get(URI(API_URI + 'objects/' + artwork['Object ID']))
    image_url = JSON.parse(response)['primaryImage']

    print_error('Failed to find image URL') and return if image_url.nil?
    width, height = FastImage.size(image_url)
    print_error('Could not get image') and return if [width, height].any?(&:nil?)
    print_error('Too Small') and return if width < output_width && height < output_height
    print_error('Not landscape') and return if require_landscape && height > width
    print_error('Not portrait') and return if require_portrait && height < width
    filename = "#{artwork['Title'].downcase.gsub(' ', '_')}.jpg"
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
    title = artwork['Title']&.strip
    artist = artwork['Artist Display Name']&.strip
    year = artwork['Object End Date']&.strip
    caption = [title, artist, year].compact.join("\n")
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

  # MetObjects.csv can be downloaded here https://github.com/metmuseum/openaccess
  def data
    @data ||= read_csv('MetObjects.csv')
  end

  private

  def read_csv(path)
    puts "\t--- Loading CSV ---"
    row_count = 475_000 # approximate collection count to avoid parsing entire CSV
    progress_bar = ProgressBar.create(total: row_count, length: 80)
    csv_data = []
    CSV.foreach(path, headers: true) do |row|
      progress_bar.increment
      csv_data << row.to_h if row["Is Public Domain"] == "True"
    end
    puts "\n\t--- CSV Loaded ---"
    csv_data
  end

  def print_error(message)
    puts message
    true
  end

  def validate_department
    response = Net::HTTP.get(URI(API_URI + 'departments'))
    valid_departments = JSON.parse(response).fetch('departments').map do |department|
      department['displayName'].downcase
    end
    unless valid_departments.include?(department)
      print_error("Invalid department: '#{department}'")
      exit
    end
  end

  def output_path(path)
    output = File.join(File.dirname(__FILE__), FOLDER_NAME, path)
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
  opts.on('--width=WIDTH', Integer)
  opts.on('--height=HEIGHT', Integer)
  opts.on('-d=DEPARTMENT', '--department=DEPARTMENT')
  opts.on('-l=LIMIT', '--limit=LIMIT', Integer)
  opts.on('--landscape')
  opts.on('--portrait')
  opts.on('--background-color=BACKGROUND_COLOR')
  opts.on('--text-color=TEXT_COLOR')
end.parse!(into: params)
p params

MetArt.new(params).fetch
