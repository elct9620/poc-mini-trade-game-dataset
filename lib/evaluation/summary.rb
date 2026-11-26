# frozen_string_literal: true

class Evaluation
  ##
  # = Evaluation::Summary
  # Turns per-row results into each metric's rate, 95% Wilson lower bound, and the rows it counts,
  # so a release gate can read the lower bound and a small sample cannot pass on luck.
  #
  # == Reference
  # - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
  ##
  module Summary
    Z = 1.96

    module_function

    # Returns the summary hash of the results.
    def call(results)
      latencies = results.map { |result| result['latency'] }.sort
      {
        'total' => results.size,
        'extract' => metrics(results.map { |result| result['extract'] }),
        'render' => metrics(results.map { |result| result['render'] }),
        'latency_mean' => latencies.empty? ? 0.0 : (latencies.sum / latencies.size).round(3),
        'latency_p95' => latencies.empty? ? 0.0 : latencies[(0.95 * (latencies.size - 1)).ceil].round(3)
      }
    end

    # Returns the 95% Wilson score lower bound of successes out of total.
    def wilson_lower(successes, total)
      return 0.0 if total.zero?

      p = successes.fdiv(total)
      denominator = 1 + (Z**2 / total)
      centre = p + (Z**2 / (2 * total))
      margin = Z * Math.sqrt((p * (1 - p) / total) + (Z**2 / (4 * total**2)))
      ((centre - margin) / denominator).round(3)
    end

    # A metric counts only the rows where it applies, so a nil check leaves its total.
    def metrics(checks)
      checks.flat_map(&:keys).uniq.to_h do |metric|
        values = checks.map { |check| check[metric] }.compact
        passed = values.count(true)
        rate = values.empty? ? 0.0 : passed.fdiv(values.size).round(3)
        [metric, { 'rate' => rate, 'lower' => wilson_lower(passed, values.size), 'total' => values.size }]
      end
    end

    private_class_method :metrics
  end
end
