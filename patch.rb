#!/usr/bin/env ruby

SIZE_X = 27
SIZE_Y = 11
PIXEL_COUNT = SIZE_X * SIZE_Y

module NextId
  def next_id
    @next_id ||= 0
  ensure
    @next_id += 1
  end
end

Channel = Struct.new(:universe, :cid)

Universe = Struct.new(:ip, :number, :channel_count, :net, :subnet)
class Universe
  extend NextId

  attr_reader :id
  attr_reader :channels
  attr_reader :pixels

  def initialize(ip, number, channel_count = 512, net = 0, subnet = 0)
    super
    @id = self.class.next_id
    @pixels = []
    @channels = (0...channel_count).map { |cid| Channel.new(self, cid) }

    @channels.each_slice(3) do |rgb_channels|
      next if rgb_channels.length < 3
      @pixels.push Pixel.new(self, *rgb_channels)
    end
  end
end

Pixel = Struct.new(:universe, :red, :green, :blue, :x, :y)
class Pixel
  extend NextId

  attr_reader :id

  def initialize(*args)
    super
    @id = self.class.next_id
  end

  def patch(x, y)
    self.x = x
    self.y = y
  end

  def patched?
    x && y
  end
end

Patchfile = Struct.new(:path, :universes, :size_x, :size_y)
class Patchfile
  def write
    File.open(path, 'w') do |f|
      f.puts '#GLEDIATOR Patch File'
      f.puts "##{Time.now}"

      f.puts matrix_size
      f.puts universe_definitions
      f.puts pixel_mappings
    end
  end

  def print_ascii_preview
    (0...size_y).each do |y|
      row = pixels.select { |p| p.y == y }.sort_by(&:x)
      cells = row.map { |p| p.id.to_s.rjust(3) }.join('|')
      puts '-' * cells.length if y == 0
      puts cells
      puts '-' * cells.length
    end
  end

  def pixels
    universes.map(&:pixels).flatten
  end

  def patch(&block)
    block.yield pixels
  end

  private

  def matrix_size
    [
      "Patch_Matrix_Size_X=#{size_x}",
      "Patch_Matrix_Size_Y=#{size_y}"
    ]
  end

  def universe_definitions
    ["Patch_Num_Unis=#{universes.count}"] + universes.map do |universe|
      universe_definition(universe)
    end
  end

  def universe_definition(universe)
    base = "Patch_Uni_ID_#{universe.id}"

    ip_definition = universe.ip.split('.').map.with_index do |part, i|
      "#{base}_IP#{i + 1}=#{part}"
    end

    ip_definition + [
      "#{base}_Uni_Nr=#{universe.number}",
      "#{base}_Net_Nr=#{universe.net}",
      "#{base}_Sub_Net_Nr=#{universe.subnet}",
      "#{base}_Num_Ch=#{universe.channel_count}"
    ]
  end

  def pixel_mappings
    universes.map(&:pixels).flatten.select(&:patched?).map do |pixel|
      base = "Patch_Pixel_X_#{pixel.x}_Y_#{pixel.y}"
      [
        "#{base}_Uni_ID=#{pixel.universe.id}",
        "#{base}_Ch_R=#{pixel.red.cid}",
        "#{base}_Ch_G=#{pixel.green.cid}",
        "#{base}_Ch_B=#{pixel.blue.cid}"
      ].join("\n")
    end
  end
end

universes = [
  Universe.new('192.168.0.20', 0),
  Universe.new('192.168.0.20', 1)
]

patchfile = Patchfile.new('patch.gled', universes, SIZE_X, SIZE_Y)

patchfile.patch do |pixels|
  pixel_index = 0

  0.upto(SIZE_Y - 1).each do |y|
    row = (0...SIZE_X).to_a.reverse
    ordered_row = row.select(&:even?) + row.select(&:odd?)

    ordered_row.each do |x|
      pixels[pixel_index].patch(x, y)
      pixel_index += 1
    end
  end
end

patchfile.print_ascii_preview
patchfile.write