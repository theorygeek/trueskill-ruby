module TrueSkill
  class PlayerPriorValuesToSkillsLayer < FactorGraphLayer
    attr_accessor :teams
    
    def initialize(parent_graph, teams)
      super(parent_graph)
      self.teams = teams
    end

    def build_layer!
      teams.each do |current_team|
        current_team_skills = []
        current_team.each do |player, rating|
          player_skill = create_skill_output_variable(player)
          local_factors << create_prior_factor(player, rating, player_skill)
          current_team_skills << player_skill
        end

        output_variables_groups << current_team_skills
      end
    end

    def create_prior_schedule
      Schedule::Sequence.new(
        "All priors",
        local_factors.map { |prior| Schedule::Step.new("Prior to Skill Step", prior, 0) }
      )
    end
    
    def create_prior_factor(player, prior_rating, skills_variable)
      GaussianFactor::Prior.new(
        prior_rating.mean, 
        prior_rating.standard_deviation ** 2 + parent_factor_graph.game_info.dynamics_factor ** 2,
        skills_variable
      )
    end

    def create_skill_output_variable(player)
      Variable::Keyed.new("#{player}'s skill", player)
    end
  end
end