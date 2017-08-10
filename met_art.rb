class MetArt
  require 'csv'
  require 'net/http'
  require 'fastimage'
  require 'open-uri'
  require 'RMagick'

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
    response = Net::HTTP.get(URI(artwork["Link Resource"]))
    match_data = response.match(/selectedOrDefaultDownload.*(http.*\.jpg)/)
    print_error('Failed') and return if match_data.nil?
    image_link = match_data.captures.first
    width, height = FastImage.size(image_link)
    print_error('Could not get size') and return if [width, height].any?(&:nil?)
    print_error('Too Small') and return if width < 2560 && height < 1440
    print_error('Not landscape') and return if height > width
    filename = "#{artwork['Title'].downcase.gsub(' ', '_')}.jpg"
    open(image_link) do |image|
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
    title = artwork['Title'].strip
    artist = artwork['Artist Display Name'].strip
    year = artwork['Object End Date'].strip
    caption = "#{title}\n#{artist}\n#{year}"
    Magick::Draw.new.annotate(image, 0, 0, 20, 15, caption) do
      self.fill = 'white'
      self.font = 'Palatino-Italic'
      self.gravity = Magick::SouthEastGravity
      self.pointsize = 30
    end
    image = background.composite(image, Magick::CenterGravity, Magick::OverCompositeOp)
    image.write("#{path.gsub('.jpg', '')}_wallpaper.jpg")
  end

  def data
    @data ||= read_csv('/Users/rfauv/Documents/MetObjects.csv').select do |h|
      h["Is Public Domain"] == "True"
    end
  end

  private

  def read_csv(path)
    csv_data = CSV.open(path).read
    keys = csv_data.shift
    csv_data.map { |items| items.map.with_index { |item, i| [keys[i], item] }.to_h }
  end

  def print_error(message)
    puts message
    true
  end
end
