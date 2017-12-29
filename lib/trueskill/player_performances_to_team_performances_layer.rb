module TrueSkill
  class PlayerPerformancesToTeamPerformancesLayer < FactorGraphLayer

    def build_layer!
      input_variables_groups.each do |current_team|
        team_performance = create_output_variable(current_team)
        local_factors << create_player_to_team_sum_factor(current_team, team_performance)
        output_variables_groups << [team_performance]
      end
    end
    
    def create_prior_schedule
      Schedule::Sequence.new(
        "all player perf to team perf schedule",
        local_factors.map { |f| Schedule::Step.new("Perf to Team Perf Step", f, 0) }
      )
    end

    def create_player_to_team_sum_factor(team_members, sum_variable)
      GaussianFactor::WeightedSum.new(
        sum_variable, 
        team_members,
        team_members.map { |key, _value| PartialPlay.partial_play_percentage(key) }
      )
    end

    def create_posterior_schedule
      result = []
      local_factors.each do |current_factor|
        (1...current_factor.messages.count).each do |current_iteration|
          result << Schedule::Step.new("team sum perf @ #{current_iteration}", current_factor, current_iteration)
        end
      end

      Schedule::Sequence.new("all of the team's sum iterations", result)
    end

    def create_output_variable(team)
      team_member_names = team.map { |key, value| key.to_s }.join(', ')
      Variable.new("Team[#{team_member_names}]'s performance")
    end
  end
end