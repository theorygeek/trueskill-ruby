module TrueSkill
  class TeamDifferencesComparisonLayer < FactorGraphLayer
    attr_accessor :epsilon, :team_ranks
    
    def initialize(parent_graph, team_ranks)
      super(parent_graph)
      self.team_ranks = team_ranks
      game_info = parent_factor_graph.game_info
      self.epsilon = DrawMargin.get_draw_margin_from_draw_probability(game_info.draw_probability, game_info.beta)
    end
    
    def build_layer!
      (0...input_variables_groups.count).each do |i|
        is_draw = (team_ranks[i] == team_ranks[i + 1])
        team_difference = input_variables_groups[i][0]

        factor = if is_draw
          GaussianFactor::Within.new(epsilon, team_difference)
        else
          GaussianFactor::GreaterThan.new(epsilon, team_difference)
        end

        local_factors << factor
      end
    end
  end
end