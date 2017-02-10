#!/usr/bin/env ruby

require 'erb'

BLINKY_IP = ARGV[0]

unless BLINKY_IP
  puts "Generates a Glediator (http://www.solderlab.de/index.php/software/glediator) patch file"
  puts "Usage: ruby patch.rb <lamp ip>"
  exit 1
end

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

  def patched_pixels
    pixels.select(&:patched?)
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
      f.puts ERB.new(DATA.read, nil, '-').result(binding)
    end
  end

  def summarize
    universes.each do |universe|
      patched_count = universe.patched_pixels.count
      puts "Universe #{universe.id}: #{patched_count * 3} channels / #{patched_count} pixels"
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

  def patched_pixels
    pixels.select(&:patched?)
  end

  def patch(&block)
    block.yield pixels
  end
end

universes = [
  Universe.new(BLINKY_IP, 0),
  Universe.new(BLINKY_IP, 1)
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

patchfile.summarize
patchfile.print_ascii_preview
patchfile.write

__END__
#GLEDIATOR Patch File
#<%= Time.now %>
Patch_Matrix_Size_X=<%= size_x %>
Patch_Matrix_Size_Y=<%= size_y %>
Patch_Num_Unis=<%= universes.count %>
<% universes.each do |universe| -%>
<% universe_base = "Patch_Uni_ID_#{universe.id}" -%>
<% universe.ip.split('.').map.with_index do |part, i| -%>
<%= universe_base %>_IP<%= i + 1 %>=<%= part %>
<% end -%>
<%= universe_base %>_Uni_Nr=<%= universe.number %>
<%= universe_base %>_Net_Nr=<%= universe.net %>
<%= universe_base %>_Sub_Net_Nr=<%= universe.subnet %>
<%= universe_base %>_Num_Ch=<%= universe.channel_count %>
<% end -%>
<% patched_pixels.each do |pixel| -%>
<% pixel_base = "Patch_Pixel_X_#{pixel.x}_Y_#{pixel.y}" -%>
<%= pixel_base %>_Uni_ID=<%= pixel.universe.id %>
<%= pixel_base %>_Ch_R=<%= pixel.red.cid %>
<%= pixel_base %>_Ch_G=<%= pixel.green.cid %>
<%= pixel_base %>_Ch_B=<%= pixel.blue.cid %>
<% end -%>
