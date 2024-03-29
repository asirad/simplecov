require 'digest/sha1'
require 'yaml'

module SimpleCov
  #
  # A simplecov code coverage result, initialized from the Hash Ruby 1.9's built-in coverage
  # library generates (Coverage.result).
  #
  class Result
    # Returns the original Coverage.result used for this instance of SimpleCov::Result
    attr_reader :original_result
    # Returns all files that are applicable to this result (sans filters!) as instances of SimpleCov::SourceFile. Aliased as :source_files
    attr_reader :files
    alias_method :source_files, :files
    # Explicitly set the Time this result has been created
    attr_writer :created_at
    # Explicitly set the command name that was used for this coverage result. Defaults to SimpleCov.command_name
    attr_writer :command_name

    # Initialize a new SimpleCov::Result from given Coverage.result (a Hash of filenames each containing an array of
    # coverage data)
    # It is possible to inject external data. Data file should be available on log/resultset.yml
    # TODO: Injection should be configurable e.g. select where file is
    def initialize(original_result)
      if File.exists?("log/resultset.yml")
        inject_data = YAML::load_file("log/resultset.yml")
        @original_result = inject_data.freeze
        @files = inject_data.map {|filename, coverage|
          SimpleCov::SourceFile.new(filename, coverage) if File.file?(filename)
        }.compact.sort_by(&:filename)
        filter!
      else
        @original_result = original_result.freeze
        @files = original_result.map {|filename, coverage|
          SimpleCov::SourceFile.new(filename, coverage) if File.file?(filename)
        }.compact.sort_by(&:filename)
        filter!
      end
    end
  
    # Returns all filenames for source files contained in this result
    def filenames
      files.map(&:filename)
    end
    
    # Returns a Hash of groups for this result. Define groups using SimpleCov.add_group 'Models', 'app/models'
    def groups
      @groups ||= SimpleCov.grouped(files)
    end
    
    # The overall percentual coverage for this result
    def covered_percent
      # Make sure that weird rounding error from #15, #23 and #24 does not occur again!
      total_lines.zero? ? 0 : 100.0 * covered_lines / total_lines
    end
    
    # Returns the count of lines that are covered
    def covered_lines
      return @covered_lines if @covered_lines
      @covered_lines = 0
      @files.each do |file|
        original_result[file.filename].each do |line_result|
          @covered_lines += 1 if line_result and line_result > 0
        end
      end
      @covered_lines
    end
    
    # Returns the count of missed lines
    def missed_lines
      return @missed_lines if @missed_lines
      @missed_lines = 0
      @files.each do |file|
        original_result[file.filename].each do |line_result|
          @missed_lines += 1 if line_result == 0
        end
      end
      @missed_lines
    end
    
    # Total count of relevant lines (covered + missed)
    def total_lines
      @total_lines ||= (covered_lines + missed_lines)
    end
    
    # Applies the configured SimpleCov.formatter on this result
    def format!
      SimpleCov.formatter.new.format(self)
    end
    
    # Defines when this result has been created. Defaults to Time.now
    def created_at
      @created_at ||= Time.now
    end
    
    # The command name that launched this result.
    # Retrieved from SimpleCov.command_name
    def command_name
      @command_name ||= SimpleCov.command_name
    end
    
    # Returns a hash representation of this Result that can be used for marshalling it into YAML
    def to_hash
      {command_name => {:original_result => original_result.reject {|filename, result| !filenames.include?(filename) }, :created_at => created_at}}
    end
    
    # Returns a yaml dump of this result, which then can be reloaded using SimpleCov::Result.from_yaml
    def to_yaml
      to_hash.to_yaml
    end
    
    # Loads a SimpleCov::Result#to_hash dump
    def self.from_hash(hash)
      command_name, data = hash.first
      result = SimpleCov::Result.new(data[:original_result])
      result.command_name = command_name
      result.created_at = data[:created_at]
      result
    end
    
    # Loads a SimpleCov::Result#to_yaml dump
    def self.from_yaml(yaml)
      from_hash(YAML.load(yaml))
    end
    
    private
  
    # Applies all configured SimpleCov filters on this result's source files
    def filter!
      @files = SimpleCov.filtered(files)
    end
  end
end
