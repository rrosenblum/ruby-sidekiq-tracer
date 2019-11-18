# Modified by SignalFx
module Sidekiq
  module Tracer
    class ClientMiddleware
      include Commons

      attr_reader :tracer, :active_span

      def initialize(tracer: nil)
        @tracer = tracer
      end

      def call(worker_class, job, queue, redis_pool)
        scope = tracer.start_active_span(
          operation_name(job), tags: tags(job, 'client')
        )
        inject(scope.span, job)
        yield
      rescue Exception => e
        if scope
          scope.span.set_tag('error', true)
          scope.span.log_kv(event: 'error', :'error.object' => e)
        end
        raise
      ensure
        scope.close if scope
      end

      private

      def inject(span, job)
        carrier = {}
        tracer.inject(span.context, OpenTracing::FORMAT_TEXT_MAP, carrier)
        job[TRACE_CONTEXT_KEY] = carrier
      end
    end
  end
end
