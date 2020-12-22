# Helper for waiting for an Async condition using a block

module RSMP
  module Wait

    def wait_for condition, timeout, &block
      raise RuntimeError.new("Can't wait for state because task is stopped") unless @task.running? 
      @task.with_timeout(timeout) do
        while task.running? do
          value = condition.wait
          result = yield value 
          return result if result   # return result of check, if not nil
        end
      end
    end   

    def capture_status_updates_or_responses task, type, options, m_id
      task.annotate "wait for status update/response"
      want = convert_status_list options[:status_list]
      result = {}
      # wait for a status update
      item = @archive.capture(task,options.merge({
        type: [type,'MessageNotAck'],
        num: 1
      })) do |item|
        message = item[:message]
        if message.is_a?(MessageNotAck) && message.attribute('oMId') == m_id
          # set result to an exception, but don't raise it.
          # this will be returned by the task and stored as the task result
          # when the parent task call wait() on the task, the exception
          # will be raised in the parent task, and caught by rspec.
          # rspec will then show the error and record the test as failed
          m_id_short = RSMP::Message.shorten_m_id m_id, 8
          result = RSMP::MessageRejected.new "Status request #{m_id_short} was rejected: #{message.attribute('rea')}"
          next true   # done, no more messages wanted
        end
        found = []
        # look through querues
        want.each_with_index do |query,i|
          # look through status items in message
          item[:message].attributes['sS'].each do |input|
            ok = status_match? query, input
            if ok
              result[query] = input
              found << i   # record which queries where matched succesfully
            end
          end
        end
        # remove queries that where matched
        found.sort.reverse.each do |i|
          want.delete_at i
        end
        want.empty? # any queries left to match?
      end
      result
    rescue Async::TimeoutError
      type_str = {'StatusUpdate'=>'update', 'StatusResponse'=>'response'}[type]
      raise RSMP::TimeoutError.new "Did not received status #{type_str} in reply to #{m_id} within #{options[:timeout]}s"
    end

    def wait_for_status_updates_or_responses parent_task, type, options={}, &block
      raise ArgumentError.new("component argument is missing") unless options[:component]
      raise ArgumentError.new("status_list argument is missing") unless options[:status_list]
      m_id = RSMP::Message.make_m_id    # make message id so we can start waiting for it

      # wait for command responses in an async task
      task = parent_task.async do |task|
        capture_status_updates_or_responses task, type, options, m_id
      end

       # call block, it should send command request using the given m_id
      yield m_id

      # wait for the response and return it, raise exception if NotAck received, it it timed out
      task.wait
    end

    def wait_for_status_updates parent_task, options={}, &block
      wait_for_status_updates_or_responses parent_task, 'StatusUpdate', options, &block
    end

    def wait_for_status_responses parent_task, options={}, &block
      wait_for_status_updates_or_responses parent_task, 'StatusResponse', options, &block
    end

    def process_command_response message
      log "Received #{message.type}", message: message, level: :log
      acknowledge message
    end

    def command_match? query, item
      return false if query[:sCI] && query[:sCI] != item['sCI']
      return false if query[:n] && query[:n] != item['n']
      if query[:s].is_a? Regexp
        return false if query[:v] && item['v'] !~ query[:v]
      else
        return false if query[:v] && item['v'] != query[:v]
      end
      true
    end

    def capture_command_responses parent_task, type, options, m_id
      task.annotate "wait for command response"
      want = options[:command_list].clone
      result = {}
      item = @archive.capture(parent_task,options.merge({
        type: [type,'MessageNotAck'],
        num: 1
      })) do |item|
        message = item[:message]
        if message.is_a?(MessageNotAck) && message.attribute('oMId') == m_id
           # and message.attribute('oMId')==m_id
          # set result to an exception, but don't raise it.
          # this will be returned by the task and stored as the task result
          # when the parent task call wait() on the task, the exception
          # will be raised in the parent task, and caught by rspec.
          # rspec will then show the error and record the test as failed
          m_id_short = RSMP::Message.shorten_m_id m_id, 8
          result = RSMP::MessageRejected.new "Command request #{m_id_short} was rejected: #{message.attribute('rea')}"
          next true   # done, no more messages wanted
        end

        found = []
        # look through querues
        want.each_with_index do |query,i|
          # look through items in message
          item[:message].attributes['rvs'].each do |input|
            ok = command_match? query, input
            if ok
              result[query] = input
              found << i   # record which queries where matched succesfully
            end
          end
        end
        # remove queries that where matched
        found.sort.reverse.each do |i|
          want.delete_at i
        end
        want.empty? # any queries left to match?
      end
      result
    rescue Async::TimeoutError
      raise RSMP::TimeoutError.new "Did not receive command response to #{m_id} within #{options[:timeout]}s"
    end

    def wait_for_command_responses parent_task, options={}, &block
      raise ArgumentError.new("component argument is missing") unless options[:component]
      raise ArgumentError.new("command_list argument is missing") unless options[:command_list]
      m_id = RSMP::Message.make_m_id    # make message id so we can start waiting for it

      # wait for command responses in an async task
      task = parent_task.async do |task|
        capture_command_responses task, 'CommandResponse', options, m_id
      end

       # call block, it should send command request using the given m_id
      yield m_id

      # wait for the response and return it, raise exception if NotAck received, it it timed out
      task.wait
    end
  end
end