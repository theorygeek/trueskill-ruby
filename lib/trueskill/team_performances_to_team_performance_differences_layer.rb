module TrueSkill
  class TeamPerformancesToTeamPerformanceDifferencesLayer < FactorGraphLayer
    
    def build_layer!
      (0...(input_variables_groups.count - 1)).each do |i|
        stronger_team = input_variables_groups[i][0]
        weaker_team = input_variables_groups[i + 1][0]

        current_difference = create_output_variable
        local_factors << create_team_performance_to_difference_factor(stronger_team, weaker_team, current_difference)

        # REVIEW: Does it make sense to have groups of one?
        output_variables_groups << [current_difference]
      end
    end

    def create_team_performance_to_difference_factor(stronger_team, weaker_team, output)
      GaussianFactor::WeightedSum.new(output, [stronger_team, weaker_team], [1.0, -1.0])
    end

    def create_output_variable
      Variable.new("Team performance difference")
    end
  end
end