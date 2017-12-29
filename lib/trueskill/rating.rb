module TrueSkill
  class Rating

    CONSERVATIVE_FACTOR = 3

    attr_reader :mean, :standard_deviation

    def initialize(mean, standard_deviation)
      @mean = mean
      @standard_deviation = standard_deviation
    end

    def conservative_rating
      mean - CONSERVATIVE_FACTOR * standard_deviation
    end

    def public_rating
      ((conservative_rating * 50) + 2000).round
    end

    def to_s
      "μ=#{mean}, σ=#{standard_deviation}"
    end
  end
end
