module TrueSkill
  module DrawMargin
    extend self

    def get_draw_margin_from_draw_probability(draw_probability, beta)
      GaussianDistribution.inverse_cumulative_to(0.5 * (draw_probability + 1), 0, 1) * Math.sqrt(2) * beta
    end
  end
end
