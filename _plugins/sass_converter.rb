# from https://raw.github.com/gist/960150/83d6d124ec1defd78d01f6806bc34fc5a4150dc9/sass_converter.rb
module Jekyll
  # Sass plugin to convert .scss to .css
  # 
  # Note: This is configured to use the new css like syntax available in sass.
  require 'sass'
  class SassConverter < Converter
    safe true
    priority :low

     def matches(ext)
      ext =~ /scss/i
    end

    def output_ext(ext)
      ".css"
    end

    def convert(content)
      begin
        puts "Performing Sass Conversion."
        engine = Sass::Engine.new(content, :syntax => :scss, :load_paths => ["./css/"], :style => :expanded)
        engine.render
      rescue StandardError => e
        puts "!!! SASS Error: " + e.message
      end
    end
  end
end
