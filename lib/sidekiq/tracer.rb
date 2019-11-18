# Modified by SignalFx
require "sidekiq"

require "sidekiq/tracer/version"
require "sidekiq/tracer/constants"
require "sidekiq/tracer/commons"
require "sidekiq/tracer/client_middleware"
require "sidekiq/tracer/server_middleware"

module Sidekiq
  module Tracer
    class << self
      def instrument(tracer: OpenTracing.global_tracer, opts: {})
        instrument_client(tracer: tracer, opts: opts)
        instrument_server(tracer: tracer, opts: opts)
      end

      def instrument_client(tracer: OpenTracing.global_tracer, opts: {})
        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::Tracer::ClientMiddleware, tracer: tracer, opts: opts
          end
        end
      end

      def instrument_server(tracer: OpenTracing.global_tracer, opts: {})
        Sidekiq.configure_server do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::Tracer::ClientMiddleware, tracer: tracer, opts: opts
          end

          config.server_middleware do |chain|
            chain.add Sidekiq::Tracer::ServerMiddleware, tracer: tracer, opts: opts
          end
        end

        if defined?(Sidekiq::Testing)
          Sidekiq::Testing.server_middleware do |chain|
            chain.add Sidekiq::Tracer::ServerMiddleware, tracer: tracer, opts: opts
          end
        end
      end
    end
  end
end
