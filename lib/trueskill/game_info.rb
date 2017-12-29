module TrueSkill
  class GameInfo
    attr_accessor :initial_mean, :initial_standard_deviation, :beta, :dynamics_factor, :draw_probability

    def self.avalon
      @avalon ||= new(initial_mean: 25.0, draw_probability: 0)
    end

    def initialize(
      initial_mean: 25.0,
      initial_standard_deviation: initial_mean / 3.0,
      beta: initial_mean / 6.0,
      dynamics_factor: initial_mean / 300.0,
      draw_probability: 0.1)

      @initial_mean = initial_mean
      @initial_standard_deviation = initial_standard_deviation
      @beta = beta
      @dynamics_factor = dynamics_factor
      @draw_probability = draw_probability
    end

    def default_rating
      Rating.new(initial_mean, initial_standard_deviation)
    end
  end
end
