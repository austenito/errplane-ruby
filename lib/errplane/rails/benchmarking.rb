require 'benchmark'
require "socket"

module Errplane
  module Rails
    module Benchmarking
      def self.included(base)
        base.send(:alias_method_chain, :perform_action, :instrumentation)
        base.send(:alias_method_chain, :view_runtime, :instrumentation)
        base.send(:alias_method_chain, :active_record_runtime, :instrumentation)
      end

      private
      def perform_action_with_instrumentation
        ms = Benchmark.ms { perform_action_without_instrumentation }
        if Errplane.configuration.instrumentation_enabled
          Errplane.rollup "controllers",
                          { :v => ms.ceil,
                            :d => {:method => "#{params[:controller]}##{params[:action]}", :server => Socket.gethostname}
                          }, true
      end

      def view_runtime_with_instrumentation
        runtime = view_runtime_without_instrumentation
        if Errplane.configuration.instrumentation_enabled
          Errplane.rollup "views",
                          { :v => runtime.split.last.to_f.ceil,
                            :d => {:method => "#{params[:controller]}##{params[:action]}", :server => Socket.gethostname}
                          }, true
        end
        runtime
      end

      def active_record_runtime_with_instrumentation
        runtime = active_record_runtime_without_instrumentation
        if Errplane.configuration.instrumentation_enabled
          Errplane.rollup "db",
                          { :v => runtime.split.last.to_f.ceil,
                            :d => {:method => "#{params[:controller]}##{params[:action]}", :server => Socket.gethostname}
                          }, true
        end
        runtime
      end
    end
  end
end
