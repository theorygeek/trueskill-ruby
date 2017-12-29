module TrueSkill
  module TwoTeamCalculator
    extend self

    WIN = 1
    DRAW = 0
    LOSE = -1

    # @param game_info Instance of TrueSkill::GameInfo
    # @param teams Array of hashes. The key in each hash is an arbitrary player object, the value is a TrueSkill::Rating.
    # @param team_ranks Array of integers indicating the team's rank in the match.
    def calculate_new_ratings(game_info, teams, team_ranks)
      raise ArgumentError, "game_info is required" if game_info.nil?

      teams, team_ranks = RankSorter.sort(teams, team_ranks)
      team1 = teams[0]
      team2 = teams[1]

      was_draw = (team_ranks[0] == team_ranks[1])
      results = {}

      update_player_ratings(
        game_info,
        results,
        team1,
        team2,
        was_draw ? DRAW : WIN)

      update_player_ratings(
        game_info,
        results,
        team2,
        team1,
        was_draw ? DRAW : LOSE)
    end

    def update_player_ratings(game_info, new_player_ratings, self_team, other_team, self_to_other_team_comparison)
      draw_margin = DrawMargin.get_draw_margin_from_draw_probability(game_info.draw_probability, game_info.beta)
      beta_squared = game_info.beta ** 2
      tau_squared = game_info.dynamics_factor ** 2

      total_players = self_team.size + other_team.size
      self_mean_sum = self_team.values.map(&:mean).sum
      other_team_mean_sum = other_team.values.map(&:mean).sum

      c = Math.sqrt(self_team.values.map { |r| r.standard_deviation ** 2 }.sum + other_team.values.map { |r| r.standard_deviation ** 2 }.sum + total_players * beta_squared)

      winning_mean = self_mean_sum
      losing_mean = other_team_mean_sum

      if self_to_other_team_comparison == LOSE
        winning_mean, losing_mean = other_team_mean_sum, self_mean_sum
      end

      mean_delta = winning_mean - losing_mean

      if self_to_other_team_comparison != DRAW
        v = TruncatedGaussianCorrectionFunctions.v_exceeds_margin(mean_delta, draw_margin, c)
        w = TruncatedGaussianCorrectionFunctions.w_exceeds_margin(mean_delta, draw_margin, c)
        rank_multiplier = self_to_other_team_comparison
      else
        v = TruncatedGaussianCorrectionFunctions.v_within_margin(mean_delta, draw_margin, c)
        w = TruncatedGaussianCorrectionFunctions.w_within_margin(mean_delta, draw_margin, c)
        rank_multiplier = 1
      end

      self_team.each do |key, value|
        previous_player_rating = value
        mean_multiplier = ((previous_player_rating.standard_deviation ** 2) + tau_squared) / c
        std_dev_multiplier = ((previous_player_rating.standard_deviation ** 2) + tau_squared) / (c ** 2)

        player_mean_delta = rank_multiplier * mean_multiplier * v
        new_mean = previous_player_rating.mean + player_mean_delta

        new_std_dev = Math.sqrt(
          ((previous_player_rating.standard_deviation ** 2) + tau_squared) * (1 - w * std_dev_multiplier)
        )

        new_player_ratings[key] = Rating.new(new_mean, new_std_dev)
      end

      new_player_ratings
    end

    def match_quality(game_info, teams)
      team1 = teams[0].values
      team1_count = team1.size

      team2 = teams[1].values
      team2_count = team2.size

      total_players = team1_count + team2_count

      beta_squared = game_info.beta ** 2

      team1_mean_sum = team1.map(&:mean).sum
      team1_std_dev_squared = team1.map { |r| r.standard_deviation ** 2 }.sum

      team2_mean_sum = team2.map(&:mean).sum
      team2_std_dev_squared = team2.map { |r| r.standard_deviation ** 2 }.sum

      sqrt_part = Math.sqrt((total_players * beta_squared) / (total_players * beta_squared + team1_std_dev_squared + team2_std_dev_squared))
      exp_part = Math.exp((-1 * ((team1_mean_sum - team2_mean_sum) ** 2)) / (2 * (total_players * beta_squared + team1_std_dev_squared + team2_std_dev_squared)))

      exp_part * sqrt_part
    end
  end
end
