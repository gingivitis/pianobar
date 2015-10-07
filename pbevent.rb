#!/usr/bin/env ruby

require_relative 'pianobar.rb'

begin
    raw_event = STDIN.read
    @pb = Pianobar.new(raw_event)

    # event = Pianobar.parse_event(raw_event)
    output = ""

    case ARGV.shift
    when 'songstart'
      output += @pb.current_song
      output += "\n"
      output += "#05b8cc"
    when 'songlove'
      output += @pb.current_song
      output += "\n"
      output += "#ffd7ff"
    end

    File.open(File.join(ENV['HOME'], "tmp", "current"), 'w') do |f|
        f.puts "#{output}"
    end

    `pkill -RTMIN+11 i3blocks`
end
