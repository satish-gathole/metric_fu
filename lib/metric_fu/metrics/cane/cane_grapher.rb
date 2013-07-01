MetricFu.reporting_require { 'graphs/grapher' }
module MetricFu
  class CaneGrapher < Grapher
    attr_accessor :cane_violations, :labels

    def initialize
      super
      @cane_violations = []
      @labels = {}
    end

    def get_metrics(metrics, date)
      if metrics && metrics.report_hash()[:cane]
        @cane_violations.push(metrics.report_hash()[:cane][:total_violations].to_i)
        @labels.update( { @labels.size => date })
      end
    end
  end
end

