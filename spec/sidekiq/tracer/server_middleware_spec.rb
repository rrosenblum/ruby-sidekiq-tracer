# Modified by SignalFx
require "spec_helper"

RSpec.describe Sidekiq::Tracer::ServerMiddleware do
  let(:tracer) { OpenTracingTestTracer.build }

  before do
    TestJob.tracer = tracer
  end

  describe "auto-instrumentation" do
    before do
      schedule_test_job
      Sidekiq::Tracer.instrument_server(tracer: tracer)
      TestJob.drain
    end

    it "creates a new span" do
      expect(tracer.spans.count).to eq(1)
    end

    it "sets operation_name to job name" do
      expect(tracer.spans.first.operation_name).to eq("TestJob")
    end

    it "sets standard OT tags" do
      span = tracer.spans.first

      expect(span.tags).to include(
        'component' => 'Sidekiq',
        'span.kind' => 'server'
      )
    end

    it "sets Sidekiq specific OT tags" do
      span = tracer.spans.first

      expect(span.tags).to include(
        'sidekiq.queue' => 'default',
        'sidekiq.retry' => 'true',
        'sidekiq.args' => 'value1, value2, 1',
        'sidekiq.jid' => /\S+/
      )
    end
  end

  describe "client-server trace context propagation" do
    let!(:root_scope) { tracer.start_active_span("root") }

    before do
      Sidekiq::Tracer.instrument(tracer: tracer)
      schedule_test_job
      TestJob.drain
      root_scope.close
    end

    it "creates spans for each part of the chain" do
      expect(tracer.spans.count).to eq(3)
    end

    it "all spans contains the same trace_id" do
      trace_ids = tracer.spans.map(&:context).map(&:trace_id).uniq

      expect(trace_ids.count).to eq(1)
    end

    it "propagates parent child relationship properly" do
      client_span = tracer.spans[1]
      server_span = tracer.spans[2]

      expect(client_span.context.parent_id).to eq(root_scope.span.context.span_id)
      expect(server_span.context.parent_id).to eq(client_span.context.span_id)
    end
  end

  describe "disabling client-server trace context propagation" do
    before do
      Sidekiq::Tracer.instrument(tracer: tracer, opts: {propagate_context: false})
      schedule_test_job
      TestJob.drain
    end

    it "creates spans for each part of the chain" do
      expect(tracer.spans.count).to eq(2)
    end

    it "client-server spans have different trace_id" do
      trace_ids = tracer.spans.map(&:context).map(&:trace_id).uniq
      expect(trace_ids.count).to eq(2)
    end

    it "doesn't propagate parent child relationship" do
      client_span = tracer.spans[0]
      server_span = tracer.spans[1]

      expect(server_span.context.parent_id).not_to eq(client_span.context.span_id)
      expect(client_span.context.parent_id).not_to eq(server_span.context.span_id)
    end
  end

  describe 'active span propagation' do
    let!(:root_scope) { tracer.start_active_span('root') }

    before do
      Sidekiq::Tracer.instrument(tracer: tracer)
      schedule_test_job
      root_scope.close
    end

    it 'sets server span as active span' do
      active_span_id = TestJob.process_job(TestJob.jobs.first)
      server_span = tracer.spans[2]

      expect(active_span_id).to eq(server_span.context.span_id)
    end
  end


  def schedule_test_job
    TestJob.perform_async("value1", "value2", 1)
  end

  class TestJob
    include Sidekiq::Worker

    class << self
      attr_accessor :tracer
    end

    def perform(*args)
      self.class.tracer.active_span.context.span_id
    end
  end
end
