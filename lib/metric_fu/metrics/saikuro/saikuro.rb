MetricFu.metrics_require { 'saikuro/saikuro_ext/sfile' }
module MetricFu

  class Saikuro < Generator
    include Rake::DSL if defined?(Rake::DSL) # rake 0.8.7 and 0.9.2 compatible

    def emit
      options_string = MetricFu.saikuro.inject("") do |options, option|
        option[0] == :input_directory ? options : options + "--#{option.join(' ')} "
      end

      MetricFu.saikuro[:input_directory].each do |input_dir|
        options_string += "--input_directory #{input_dir} "
      end

      saikuro_bin= $:.map{|d| d+'/../bin/saikuro'}.select{|f| File.exists? f}.first || 'saikuro'
      mf_debug(capture_output do
        sh %{#{saikuro_bin} #{options_string}} do |ok, response|
          unless ok
            mf_log "Saikuro failed with exit status: #{response.exitstatus}"
          end
        end
      end)
    end

    def capture_output(&block)
      old_stdout = STDOUT.clone
      pipe_r, pipe_w = IO.pipe
      pipe_r.sync    = true
      output         = ""
      reader = Thread.new do
        begin
          loop do
            output << pipe_r.readpartial(1024)
          end
        rescue EOFError
        end
      end
      STDOUT.reopen(pipe_w)
      yield
    ensure
      STDOUT.reopen(old_stdout)
      pipe_w.close
      reader.join
      return output
    end

    def format_directories
      dirs = MetricFu.saikuro[:input_directory].join(" | ")
      "\"#{dirs}\""
    end

    def analyze
      @files = sort_files(assemble_files)
      @classes = sort_classes(assemble_classes(@files))
      @meths = sort_methods(assemble_methods(@files))
    end

    def to_h
      files = @files.map do |file|
        my_file = file.to_h

        f = file.filepath
        f.gsub!(%r{^#{metric_directory}/}, '')
        f << "/#{file.filename}"

        my_file[:filename] = f
        my_file
      end
      @saikuro_data = {:files => files,
                       :classes => @classes.map {|c| c.to_h},
                       :methods => @meths.map {|m| m.to_h}
                      }
      {:saikuro => @saikuro_data}
    end

    def per_file_info(out)
      @saikuro_data[:files].each do |file_data|
        next if File.extname(file_data[:filename]) == '.erb' || !File.exists?(file_data[:filename])
        begin
          line_numbers = MetricFu::LineNumbers.new(File.open(file_data[:filename], 'r').read)
        rescue StandardError => e
          raise e unless e.message =~ /you shouldn't be able to get here/
          mf_log "ruby_parser blew up while trying to parse #{file_path}. You won't have method level Saikuro information for this file."
          next
        end

        out[file_data[:filename]] ||= {}
        file_data[:classes].each do |class_data|
          class_data[:methods].each do |method_data|
            line = line_numbers.start_line_for_method(method_data[:name])
            out[file_data[:filename]][line.to_s] ||= []
            out[file_data[:filename]][line.to_s] << {:type => :saikuro,
                                                      :description => "Complexity #{method_data[:complexity]}"}
          end
        end
      end
    end

    private
    def sort_methods(methods)
      methods.sort_by {|method| method.complexity.to_i}.reverse
    end

    def assemble_methods(files)
      methods = []
      files.each do |file|
        file.elements.each do |element|
          element.defs.each do |defn|
            defn.name = "#{element.name}##{defn.name}"
            methods << defn
          end
        end
      end
      methods
    end

    def sort_classes(classes)
      classes.sort_by {|k| k.complexity.to_i}.reverse
    end

    def assemble_classes(files)
      files.map {|f| f.elements}.flatten
    end

    def sort_files(files)
      files.sort_by do |file|
        file.elements.
             max {|a,b| a.complexity.to_i <=> b.complexity.to_i}.
             complexity.to_i
      end.reverse
    end

    def assemble_files
      files = []
      Dir.glob("#{metric_directory}/**/*.html").each do |path|
        if MetricFu::Saikuro::SFile.is_valid_text_file?(path)
          file = MetricFu::Saikuro::SFile.new(path)
          if file
            files << file
          end
        end
      end
      files
    end

  end

end
