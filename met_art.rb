class MetArt
  require 'fileutils'
  require 'csv'
  require 'fastimage'
  require 'open-uri'
  require 'rmagick'
  require 'json'

  FOLDER_NAME = 'wallpapers'.freeze
  API_URI = 'https://collectionapi.metmuseum.org/public/collection/v1/objects/'.freeze

  def initialize
    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), FOLDER_NAME))
  end

  def fetch(total: 10, department: nil)
    artworks = if department.nil?
      data
    else
      data.select { |h| h["Department"] == department }
    end
    images_downloaded = 0
    while images_downloaded < total && !artworks.empty?
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
    response = Net::HTTP.get(URI(API_URI + artwork['Object ID']))
    image_url = JSON.parse(response)['primaryImage']

    print_error('Failed to find image URL') and return if image_url.nil?
    width, height = FastImage.size(image_url)
    print_error('Could not get image') and return if [width, height].any?(&:nil?)
    print_error('Too Small') and return if width < 2560 && height < 1440
    print_error('Not landscape') and return if height > width
    filename = "#{artwork['Title'].downcase.gsub(' ', '_')}.jpg"
    open(image_url) do |image|
      File.open(filename, 'wb') do |file|
        file.puts image.read
      end
    end
    filename
  end

  def format_image(path, artwork)
    background = Magick::Image.new(2560, 1440) { self.background_color = 'black' }
    image = Magick::ImageList.new(path)
    image.change_geometry!('2560x1440') do |cols, rows, img|
     img.resize!(cols, rows)
    end
    title = artwork['Title']&.strip
    artist = artwork['Artist Display Name']&.strip
    year = artwork['Object End Date']&.strip
    caption = [title, artist, year].compact.join("\n")
    Magick::Draw.new.annotate(image, 0, 0, 20, 15, caption) do
      self.fill = 'white'
      self.font = 'Palatino-Italic'
      self.gravity = Magick::SouthEastGravity
      self.pointsize = 30
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
    csv_data = []
    CSV.foreach(path, headers: true) do |row|
      csv_data << row.to_h if row["Is Public Domain"] == "True"
    end
    csv_data
  end

  def print_error(message)
    puts message
    true
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

MetArt.new.fetch
