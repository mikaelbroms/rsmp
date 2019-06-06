module RSMP
  class Logger

    attr_reader :archive
    attr_accessor :archive_mutex, :archive_condition_variable

    def initialize server, settings
      @server = server
      @settings = settings
      @archive = []
      @messages = []

      @archive_mutex = Mutex.new
      @archive_condition_variable = ConditionVariable.new
    end

    def synchronize_archive &block
      @archive_mutex.synchronize block
    end

    def output? item
      return false if @settings["active"] == false
      return false if @settings["info"] == false && item[:level] == :info
      if item[:message]
        type = item[:message].type
        ack = type == "MessageAck" || type == "MessageNotAck"
        if @settings["watchdogs"] == false
          return false if type == "Watchdog"
          if ack
            return false if item[:message].original.type == "Watchdog"
          end
        end
        return false if ack && @settings["acknowledgements"] == false
      end
      true
    end

    def build_output item
      parts = []
      parts << item[:timestamp].to_s.ljust(24) unless @settings["timestamp"] == false
      parts << item[:ip].to_s.ljust(22) unless @settings["ip"] == false
      parts << item[:site_id].to_s.ljust(13) unless @settings["site_id"] == false
      parts << item[:level].to_s.capitalize.ljust(7) unless @settings["level"] == false
      parts << item[:direction].to_s.capitalize.ljust(4) unless @settings["direction"] == false
      unless @settings["id"] == false
        length = 4
        if item[:message]
          parts << item[:message].m_id[0..length-1].ljust(length+1)
        else
          parts << " "*(length+1)
        end
      end
      parts << item[:str].strip unless @settings["text"] == false
      parts << item[:message].json unless @settings["json"] == false || item[:message] == nil

      parts.join(' ').chomp(' ')
    end

    def output level, str
      return if str.empty? || /^\s+$/.match(str)
      streams = [$stdout]
      streams << $stderr if level == :error
      streams.each do |stream|
        stream.puts str
      end
    end

    def log item
      @archive_mutex.synchronize do
        @archive << item.clone
        @archive_condition_variable.broadcast
      end
      output item[:level], build_output(item) if output? item
    end

    def find options={}
      @archive.select do |item|
        # note: next(false) means we move to the next iteration, returning true for this item
        next(false) if options[:earliest] && item[:timestamp] < options[:earliest]
        next(false) if options[:with_message] && !(item[:direction] && item[:message])
        true
      end
    end

    def wait_for_messages options
      earliest = options[:earliest]
      num = options[:num]
      timeout = options[:timeout]

      start = Time.now
      @archive_mutex.synchronize do
        loop do
          m = find(earliest: earliest, with_message: true).map { |item| item[:message]}
          left = timeout + (start - Time.now)
          return m, m.size if m.size >=num or left <= 0
          @archive_condition_variable.wait(@archive_mutex,left)
        end
      end
    end
  end
end