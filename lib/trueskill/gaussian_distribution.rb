module TrueSkill
  class GaussianDistribution
    attr_accessor :mean, :standard_deviation, :variance, :precision, :precision_mean

    def initialize(mean, standard_deviation)
      self.mean = mean
      self.standard_deviation = standard_deviation
      self.variance = standard_deviation ** 2
      self.precision = 1.0 / variance
      self.precision_mean = precision * mean
    end

    def self.from_precision_mean(precision_mean, precision)
      precision = precision.to_f
      precision_mean = precision_mean.to_f
      
      variance = 1.0 / precision
      standard_deviation = Math.sqrt(variance)
      mean = precision_mean / precision

      result = new(mean, standard_deviation)
      result.precision = precision
      result.precision_mean = precision_mean
      result.variance = variance
      
      result
    end

    def inspect
      "mean=#{mean} stdev=#{standard_deviation} variance=#{variance} precision=#{precision} precision_mean=#{precision_mean}"
    end

    alias to_s inspect

    def normalization_constant
      1.0 / (Math.sqrt(2 * Math::PI) * standard_deviation)
    end

    def *(other)
      GaussianDistribution.from_precision_mean(
        precision_mean + other.precision_mean,
        precision + other.precision
      )
    end

    def self.absolute_difference(left, right)
      [
        (left.precision_mean - right.precision_mean).abs,
        Math.sqrt((left.precision - right.precision).abs)
      ].max
    end

    def -(other)
      GaussianDistribution.absolute_difference(self, other)
    end

    def /(denominator)
      GaussianDistribution.from_precision_mean(precision_mean - denominator.precision_mean, precision - denominator.precision)
    end

    LOG_SQRT_2_PI = Math.log(Math.sqrt(2 * Math::PI))

    def self.log_product_normalization(left, right)
      return 0.to_f if left.precision == 0 || right.precision == 0
      
      variance_sum = left.variance + right.variance
      mean_difference = left.mean - right.mean

      -LOG_SQRT_2_PI - (Math.log(variance_sum) / 2.0) - ((mean_difference ** 2) / (2.0 * variance_sum))  
    end

    def self.log_ratio_normalization(numerator, denominator)
      return 0.to_f if numerator.precision == 0 || denominator.precision == 0
    
      variance_difference = denominator.variance - numerator.variance
      mean_difference = numerator.mean - denominator.mean

      Math.log(denominator.variance) + LOG_SQRT_2_PI - Math.log(variance_difference) / 2.0 + (mean_difference ** 2) / (2 * variance_difference)
    end

    def self.cumulative_to(x, mean = 0, standard_deviation = 1)
      invsqrt2 = -0.707106781186547524400844362104
      result = error_function_cumulative_to(invsqrt2 * x)
      0.5 * result
    end

    def self.inverse_cumulative_to(x, mean = 0, standard_deviation = 1)
      mean - Math.sqrt(2) * standard_deviation * inverse_error_function_cumulative_to(2 * x)
    end

    def self.at(x, mean = 0, standard_deviation = 1)
      multiplier = 1.0 / (standard_deviation * Math.sqrt(2 * Math::PI))
      exp_part = Math.exp((-1.0 * ((x - mean) ** 2.0)) / (2 * (standard_deviation ** 2)))
      multiplier * exp_part
    end

    def self.inverse_error_function_cumulative_to(p)
      return -100.0 if p >= 2.0
      return 100.0 if p <= 0.0

      pp = (p < 1.0) ? p : 2 - p
      t = Math.sqrt(-2 * Math.log(pp / 2.0))
      x = -0.70711 * ((2.30753 + t * 0.27061) / (1.0 + t * (0.99229 + t * 0.04481)) - t)

      j = 0
      while j < 2
        err = error_function_cumulative_to(x) - pp
        x += err / (1.12837916709551257 * Math.exp(-(x * x)) - x * err)
        j += 1
      end

      return p < 1.0 ? x : -x
    end

    def self.error_function_cumulative_to(x)
      z = x.abs
      t = 2.0 / (2.0 + z)
      ty = 4 * t - 2

      coefficients = [
        -1.3026537197817094, 6.4196979235649026e-1,
         1.9476473204185836e-2, -9.561514786808631e-3, -9.46595344482036e-4,
         3.66839497852761e-4, 4.2523324806907e-5, -2.0278578112534e-5,
         -1.624290004647e-6, 1.303655835580e-6, 1.5626441722e-8, -8.5238095915e-8,
         6.529054439e-9, 5.059343495e-9, -9.91364156e-10, -2.27365122e-10,
         9.6467911e-11, 2.394038e-12, -6.886027e-12, 8.94487e-13, 3.13092e-13,
         -1.12708e-13, 3.81e-16, 7.106e-15, -1.523e-15, -9.4e-17, 1.21e-16, -2.8e-17
      ]

      ncof = coefficients.size
      d = 0.0
      dd = 0.0

      coefficients[1..-1].reverse_each do |val|
        tmp = d
        d = ty * d - dd + val
        dd = tmp
      end

      ans = t * Math.exp(-z * z + 0.5 * (coefficients[0] + ty * d) - dd)
      x >= 0.0 ? ans : (2.0 - ans)
    end
  end
end
