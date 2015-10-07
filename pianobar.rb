#!/usr/bin/env ruby

class Pianobar
    CONTROLS = {
        :next_song  => 'n',
        :pause      => 'p',
        :change_station => 's',
        :love_song  => '+',
        :ban_song => '-'
    }

    def initialize(event)
        @fifo = File.join(ENV['HOME'], 'tmp', 'pianobar')
        `mkfifo #{@fifo}` unless File.exist? @fifo

        @fields = parse_event(event)
    end

    CONTROLS.each do |name,val|
        send :define_method, name do
            send_command(val)
        end
    end

    def send_command(com)
        `echo '#{com.to_s}' > #{@fifo}`
    end

    def parse_event(event)
        fields = event.split("\n")
        return nil unless fields
        fields.map! { |f| f.split('=') }
        # Remove all the empty fields, they'll end up nil anyways
        fields.reject! { |f| f.length != 2 }
        # Create a hash, and fill it
        # Field names are all symbols
        result = {}
        fields.each { |f| result[f[0].to_sym] = f[1] }
        return result
    end

    def current_song
      # "#{(@fields[:artist] + ' - ' + @fields[:title]).upcase.gsub(/&/, '&amp;')}\n"
      "#{(@fields[:artist] + ' - ' + @fields[:title]).upcase}\n"
    end
end
