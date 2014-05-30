require 'log4r'

class RFlow
  class Logger
    extend Forwardable
    include Log4r

    LOG_PATTERN_FORMAT = '%l [%d] %x (%p) - %M'
    DATE_METHOD = 'xmlschema(6)'
    LOG_PATTERN_FORMATTER = PatternFormatter.new :pattern => LOG_PATTERN_FORMAT, :date_method => DATE_METHOD

    private
    attr_accessor :internal_logger
    attr_accessor :log_file_path, :log_level, :log_name

    public

    # make sure Log4r is initialized; ignored if custom levels are already set
    Log4r.define_levels(*Log4rConfig::LogLevels)

    # Delegate log methods to internal logger
    def_delegators :@internal_logger,
      *Log4r::LNAMES.map(&:downcase).map(&:to_sym),
      *Log4r::LNAMES.map(&:downcase).map {|n| "#{n}?".to_sym }

    def initialize(config, include_stdout = false)
      @log_file_path = config['rflow.log_file_path']
      @log_level = config['rflow.log_level']
      @log_name = (config['rflow.application_name'] || File.basename(log_file_path))

      establish_internal_logger
      hook_up_logfile
      hook_up_stdout if include_stdout
      register_logging_context

      internal_logger
    end

    def reopen
      # TODO: Make this less of a hack, although Log4r doesn't support
      # it, so it might be permanent
      log_file = Outputter['rflow.log_file'].instance_variable_get(:@out)
      File.open(log_file.path, 'a') { |tmp_log_file| log_file.reopen(tmp_log_file) }
    end

    def close
      Outputter['rflow.log_file'].close
    end

    def toggle_log_level
      original_log_level = LNAMES[logger.level]
      new_log_level = (original_log_level == 'DEBUG' ? log_level : 'DEBUG')

      internal_logger.warn "Changing log level from #{original_log_level} to #{new_log_level}"
      internal_logger.level = LNAMES.index new_log_level
    end

    private
    def establish_internal_logger
      @internal_logger = Log4r::Logger.new(log_name).tap do |logger|
        logger.level = LNAMES.index log_level
        logger.trace = true
      end
    end

    def hook_up_logfile
      begin
        internal_logger.add FileOutputter.new('rflow.log_file', :filename => log_file_path, :formatter => LOG_PATTERN_FORMATTER)
      rescue Exception => e
        raise ArgumentError, "Log file '#{File.expand_path log_file_path}' problem: #{e.message}\b#{e.backtrace.join("\n")}"
      end
    end

    def hook_up_stdout
      internal_logger.add StdoutOutputter.new('rflow_stdout', :formatter => LOG_PATTERN_FORMATTER)
    end

    def register_logging_context
      Log4r::NDC.clear
      Log4r::NDC.push(log_name)
    end
  end
end
