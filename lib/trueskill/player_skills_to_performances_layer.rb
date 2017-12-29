module TrueSkill
  class PlayerSkillsToPerformancesLayer < FactorGraphLayer

    def build_layer!
      input_variables_groups.each do |current_team|
        current_team_player_performances = []

        current_team.each do |player_skill|
          player_performance = create_output_variable(player_skill.key)
          local_factors << create_likelihood(player_skill, player_performance)
          current_team_player_performances << player_performance
        end

        output_variables_groups << current_team_player_performances
      end
    end
    
    def create_likelihood(player_skill, player_performance)
      GaussianFactor::Likelihood.new(parent_factor_graph.game_info.beta ** 2, player_performance, player_skill)
    end
    
    def create_output_variable(player)
      Variable::Keyed.new("#{player}'s performance", player)
    end
    
    def create_prior_schedule
      Schedule::Sequence.new(
        "All skill to performance sending",
        local_factors.map { |likelihood| Schedule::Step.new("Skill to Perf step", likelihood, 0) }
      )
    end
    
    def create_posterior_schedule
      Schedule::Sequence.new(
        "All skill to performance sending",
        local_factors.map { |likelihood| Schedule::Step.new("name", likelihood, 1) }
      )
    end  
  end
end