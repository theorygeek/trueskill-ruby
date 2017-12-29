module TrueSkill
  module TruncatedGaussianCorrectionFunctions
    extend self

    def v_exceeds_margin(team_performance_difference, draw_margin, c = nil)
      team_performance_difference /= c unless c.nil?
      draw_margin /= c unless c.nil?

      denominator = GaussianDistribution.cumulative_to(team_performance_difference - draw_margin)

      if denominator < 2.222758749e-162
        return -team_performance_difference + draw_margin
      end

      GaussianDistribution.at(team_performance_difference - draw_margin) / denominator
    end

    def w_exceeds_margin(team_performance_difference, draw_margin, c = nil)
      team_performance_difference /= c unless c.nil?
      draw_margin /= c unless c.nil?

      denominator = GaussianDistribution.cumulative_to(team_performance_difference - draw_margin)

      if denominator < 2.222758749e-162
        if team_performance_difference < 0.0
          return 1.0
        end
        return 0.0
      end

      v_win = v_exceeds_margin(team_performance_difference, draw_margin)
      v_win * (v_win + team_performance_difference - draw_margin)
    end

    def v_within_margin(team_performance_difference, draw_margin, c = nil)
      team_performance_difference /= c unless c.nil?
      draw_margin /= c unless c.nil?

      team_performance_difference_absolute_value = team_performance_difference.abs
      denominator = GaussianDistribution.cumulative_to(draw_margin - team_performance_difference_absolute_value) - GaussianDistribution.cumulative_to(-draw_margin - team_performance_difference_absolute_value)

      if denominator < 2.222758749e-162
        if team_performance_difference < 0.0
          return -team_performance_difference - draw_margin
        end
        return -team_performance_difference + draw_margin
      end

      numerator = GaussianDistribution.at(-draw_margin - team_performance_difference_absolute_value) - GaussianDistribution.at(draw_margin - team_performance_difference_absolute_value)

      if team_performance_difference < 0.0
        -numerator / denominator
      else
        numerator / denominator
      end
    end

    def w_within_margin(team_performance_difference, draw_margin, c = nil)
      team_performance_difference /= c unless c.nil?
      draw_margin /= c unless c.nil?

      team_performance_difference_absolute_value = team_performance_difference.abs
      denominator = GaussianDistribution.cumulative_to(draw_margin - team_performance_difference_absolute_value) - GaussianDistribution.cumulative_to(-draw_margin - team_performance_difference_absolute_value)

      if denominator < 2.222758749e-162
        return 1.0
      end

      vt = v_within_margin(team_performance_difference_absolute_value, draw_margin)

      (vt ** 2) + ((draw_margin - team_performance_difference_absolute_value) * GaussianDistribution.at(draw_margin - team_performance_difference_absolute_value) - (-draw_margin - team_performance_difference_absolute_value) * GaussianDistribution.at(-draw_margin - team_performance_difference_absolute_value)) / denominator
    end
  end
end
