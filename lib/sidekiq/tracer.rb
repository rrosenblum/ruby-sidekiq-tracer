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
      def instrument(tracer: OpenTracing.global_tracer)
        instrument_client(tracer: tracer)
        instrument_server(tracer: tracer)
      end

      def instrument_client(tracer: OpenTracing.global_tracer)
        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::Tracer::ClientMiddleware, tracer: tracer
          end
        end
      end

      def instrument_server(tracer: OpenTracing.global_tracer)
        Sidekiq.configure_server do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::Tracer::ClientMiddleware, tracer: tracer
          end

          config.server_middleware do |chain|
            chain.add Sidekiq::Tracer::ServerMiddleware, tracer: tracer
          end
        end

        if defined?(Sidekiq::Testing)
          Sidekiq::Testing.server_middleware do |chain|
            chain.add Sidekiq::Tracer::ServerMiddleware, tracer: tracer
          end
        end
      end
    end
  end
end
