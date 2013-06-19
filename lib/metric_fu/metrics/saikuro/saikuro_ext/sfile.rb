MetricFu.metrics_require { 'saikuro/saikuro_ext/parsing_element' }
module MetricFu
  class Saikuro < Generator; end
  class Saikuro::SFile

    attr_reader :elements

    def initialize(path)
      @path = path
      @file_handle = File.open(@path, "r")
      @elements = []
      get_elements
    ensure
      @file_handle.close if @file_handle
    end

    def self.is_valid_text_file?(path)
      File.open(path, "r") do |f|
        if f.eof? || !f.readline.match(/--/)
          return false
        else
          return true
        end
      end
    end

    def filename
      File.basename(@path, '_cyclo.html')
    end

    def filepath
      File.dirname(@path)
    end

    def to_h
      merge_classes
      {:classes => @elements}
    end

    def get_elements
      begin
        while (line = @file_handle.readline) do
          return [] if line.nil? || line !~ /\S/
          element ||= nil
          if line.match /START/
            unless element.nil?
              @elements << element
              element = nil
            end
            line = @file_handle.readline
            element = MetricFu::Saikuro::ParsingElement.new(line)
          elsif line.match /END/
            @elements << element if element
            element = nil
          else
            element << line if element
          end
        end
      rescue EOFError
        nil
      end
    end


    def merge_classes
      new_elements = []
      get_class_names.each do |target_class|
        elements = @elements.find_all {|el| el.name == target_class }
        complexity = 0
        lines = 0
        defns = []
        elements.each do |el|
          complexity += el.complexity.to_i
          lines += el.lines.to_i
          defns << el.defs
        end

        new_element = {:class_name => target_class,
                       :complexity => complexity,
                       :lines => lines,
                       :methods => defns.flatten.map {|d| d.to_h}}
        new_element[:methods] = new_element[:methods].
                                sort_by {|x| x[:complexity] }.
                                reverse

        new_elements << new_element
      end
      @elements = new_elements if new_elements
    end

    def get_class_names
      class_names = []
      @elements.each do |element|
        unless class_names.include?(element.name)
          class_names << element.name
        end
      end
      class_names
    end

  end
end
