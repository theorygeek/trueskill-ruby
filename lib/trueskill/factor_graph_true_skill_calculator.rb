module TrueSkill
  module FactorGraphTrueSkillCalculator
    extend self

    def build_factor_graph(game_info, teams, team_ranks)
      factor_graph = FactorGraph.new(game_info, teams, team_ranks)
      factor_graph.build_graph!
      factor_graph.run_schedule!

      factor_graph
    end

    # @param game_info Instance of TrueSkill::GameInfo
    # @param teams Array of hashes. The key in each hash is an arbitrary player object, the value is a TrueSkill::Rating.
    # @param team_ranks Array of integers indicating the team's rank in the match.
    def calculate_new_ratings(game_info, teams, team_ranks)
      factor_graph = build_factor_graph(game_info, teams, team_ranks)
      factor_graph.updated_ratings
    end

    def outcome_probability(game_info, teams, team_ranks)
      factor_graph = build_factor_graph(game_info, teams, team_ranks)
      factor_graph.outcome_probability
    end

    def match_quality(game_info, teams)
      # We need to create the A matrix which is the player team assigments.
      skills_matrix = get_player_covariance_matrix(teams)
      mean_vector = get_player_means_vector(teams)
      mean_vector_transpose = mean_vector.transpose
      
      player_team_assignments_matrix = create_player_team_assignment_matrix(teams, mean_vector.rows)
      player_team_assignments_matrix_transpose = player_team_assignments_matrix.transpose
      
      beta_squared = game_info.beta ** 2
      
      start = mean_vector_transpose * player_team_assignments_matrix
      a_ta = (player_team_assignments_matrix_transpose * beta_squared) * player_team_assignments_matrix
      a_tsa = player_team_assignments_matrix_transpose * skills_matrix * player_team_assignments_matrix
      middle = a_ta + a_tsa
      
      middle_inverse = middle.inverse
      
      ending = player_team_assignments_matrix_transpose * mean_vector
      
      exp_part_matrix = (start * middle_inverse * ending) * -0.5
      exp_part = exp_part_matrix.determinant
      
      sqrt_part_numerator = a_ta.determinant
      sqrt_part_denominator = middle.determinant
      sqrt_part = sqrt_part_numerator / sqrt_part_denominator

      Math.exp(exp_part) * Math.sqrt(sqrt_part)
    end

    def get_player_covariance_matrix(teams)
      # This is a square matrix whose diagonal values represent the variance (square of standard deviation) of all
      # players.

      Matrix::Diagonal.new(get_player_rating_values(teams) { |rating| rating.standard_deviation ** 2 })
    end

    def get_player_means_vector(teams)
      # A simple vector of all the player means.
      Matrix::Vector.new(get_player_rating_values(teams) { |rating| rating.mean })
    end

    def get_player_rating_values(teams)
      player_rating_values = []

      teams.each do |current_team|
        current_team.each_value do |current_rating|
          player_rating_values << yield(current_rating)
        end
      end
  
      player_rating_values
    end

    def create_player_team_assignment_matrix(teams, total_players)
      # The team assignment matrix is often referred to as the "A" matrix. It's a matrix whose rows represent the players
      # and the columns represent teams. At Matrix[row, column] represents that player[row] is on team[col]
      # Positive values represent an assignment and a negative value means that we subtract the value of the next 
      # team since we're dealing with pairs. This means that this matrix always has teams - 1 columns.
      # The only other tricky thing is that values represent the play percentage.

      # For example, consider a 3 team game where team1 is just player1, team 2 is player 2 and player 3, and 
      # team3 is just player 4. Furthermore, player 2 and player 3 on team 2 played 25% and 75% of the time 
      # (e.g. partial play), the A matrix would be:

      # A = this 4x2 matrix:
      # |  1.00  0.00 |
      # | -0.25  0.25 |
      # | -0.75  0.75 |
      # |  0.00 -1.00 |

      player_assignments = []
      total_previous_players = 0
      teams = teams.to_a

      (0...(teams.count - 1)).each do |i|
        current_team = teams[i]

        # Need to add in 0's for all the previous players, since they're not
        # on this team
        current_row_values = Array.new(total_previous_players) { 0.0 }
        player_assignments << current_row_values

        current_team.each do |player, rating|
          current_row_values << PartialPlay.partial_play_percentage(player)
          # indicates the player is on the team
          total_previous_players += 1
        end

        next_team = teams[i + 1]
        next_team.each do |next_player, next_rating|
          # Add a -1 * playing time to represent the difference
          current_row_values << -1 * PartialPlay.partial_play_percentage(next_player)
        end
      end

      Matrix.new(rows: total_players, columns: teams.count - 1, column_values: player_assignments)
    end
  end
end