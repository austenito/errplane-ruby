require 'thread'
require "net/http"
require "uri"
require "base64"

module Errplane
  class Worker
    MAX_POST_POINTS = 200
    MAX_TIME_SERIES_NAME_LENGTH = 255

    class << self
      include Errplane::Logger

      def post_data(data)
        if Errplane.configuration.ignore_current_environment?
          log :debug, "Current environment is ignored, skipping POST."
          return false
        else
          begin
            Errplane.api.post(data)
          rescue => e
            log :error, "Error calling API: #{e.inspect}"
          end
        end
      end

      def current_threads()
        Thread.list.select {|t| t[:errplane]}
      end

      def current_thread_count()
        Thread.list.count {|t| t[:errplane]}
      end

      def spawn_threads()
        Errplane.configuration.queue_worker_threads.times do |thread_num|
          log :debug, "Spawning background worker thread #{thread_num}."

          Thread.new do
            Thread.current[:errplane] = true

            at_exit do
              log :debug, "Thread exiting, flushing queue."
              check_background_queue(thread_num) until Errplane.queue.empty?
            end

            while true
              sleep Errplane.configuration.queue_worker_polling_interval
              check_background_queue(thread_num)
            end
          end
        end
      end

      def check_background_queue(thread_num = 0)
        log :debug, "Checking background queue on thread #{thread_num} (#{current_threads.count} active)"

        begin
          data = []

          while data.size < MAX_POST_POINTS && !Errplane.queue.empty?
            p = Errplane.queue.pop(true) rescue next;
            log :debug, "Found data in the queue! (#{p[:n]})"

            begin
              if p[:n].size > MAX_TIME_SERIES_NAME_LENGTH
                log :error, "Time series name too long! Discarding data for: #{p[:n]}"
              else
                data.push p
              end
            rescue => e
              log :info, "Instrumentation Error! #{e.inspect} #{e.backtrace.first}"
            end
          end

          post_data(data) unless data.empty?
        end while Errplane.queue.length > MAX_POST_POINTS
      end
    end
  end
end
