require 'pry'
require 'set'

class PossibleGame
  attr_reader :teams, :quality, :game_info, :possible_outcomes, :winning_ranking

  # @param teams Array of team hashes
  # @param quality Quality score of the match
  def initialize(teams:, quality:, game_info:)
    raise ArgumentError, "teams must be an Array" unless teams.is_a?(Array)
    raise ArgumentError, "quality must be Float" unless quality.is_a?(Float)
    raise ArgumentError, "game_info must be TrueSkill::GameInfo" unless game_info.is_a?(TrueSkill::GameInfo)

    @teams = teams.each(&:freeze).freeze
    @quality = quality
    @game_info = game_info

    @possible_outcomes = {}
    (1..teams.size).to_a.permutation.each do |ranking|
      possible_outcomes[ranking] = TrueSkill::FactorGraphTrueSkillCalculator.outcome_probability(
        game_info,
        teams,
        ranking
      )
    end

    @winning_ranking = possible_outcomes.max_by { |k, v| v }[0]
    losers
    freeze
  end

  def winners
    teams[winning_ranking.index(1)].keys
  end

  def probability
    possible_outcomes[winning_ranking]
  end

  def losers
    return @losers if defined?(@losers)
    
    @losers = []
    winning_ranking.each_with_index do |rank, index|
      next if rank == 1
      @losers << teams[index].keys
    end
    
    @losers
  end
end

class Player
  attr_accessor :name, :rating, :games_played, :games_won

  def initialize(name)
    @name = name
    @rating = TrueSkill::Rating.new(25.0, 25.0 / 3.0)
    @games_played = 0
    @games_won = 0
  end

  LOW = (25.0 / 3.0)
  MEDIUM = LOW / 1.25
  HIGH = LOW / 1.75

  def confidence
    if rating.standard_deviation <= HIGH
      'high'
    elsif rating.standard_deviation <= MEDIUM
      'medium'
    else
      'low'
    end
  end

  def winrate
    return Float::INFINITY if games_played == 0
    (games_won.to_f / games_played.to_f * 100.0).round
  end
end

class Leaderboard
  attr_reader :game_info
  def initialize(game_info)
    @game_info = game_info.freeze
  end

  # Adds a new game to the leaderboard.
  # @param game Should be an array of arrays of strings that representing the teams in
  # order of their finish.
  def <<(game)
    calculate_new_ratings(game)
  end

  def add_player(name)
    player_rating[name]
    nil
  end

  HEADLINE = ['#', 'Player', 'Mean', 'Confidence', 'Games Won', 'Games Played', 'Win Rate']
  SPACER = '  '

  def show
    sorted = player_rating.sort_by { |player_name, player| [-player.rating.mean, player.rating.standard_deviation] }

    output = [HEADLINE]
    sorted.each_with_index do |(player_name, player), index|
      output << [
        index + 1,
        player_name,
        player.rating.mean.round(1),
        "#{player.confidence} (#{player.rating.standard_deviation.round(1)})",
        player.games_won,
        player.games_played,
        player.winrate
      ]
    end

    display(output)
  end

  def possible_games(players_per_team: 1, teams: 3)
    players = teams * players_per_team

    matches = Set.new
    player_rating.keys.combination(players).each do |game_players|
      construct_possible_teams(game_players, players / teams) do |possible_game|
        matches.add(possible_game.to_set)
      end
    end

    result = matches.map do |teams|
      team_ratings = teams.map { |players| build_team(players) }
      quality = TrueSkill::FactorGraphTrueSkillCalculator.match_quality(game_info, team_ratings)

      PossibleGame.new(
        teams: team_ratings,
        quality: quality,
        game_info: game_info
      )
    end

    result.sort_by { |r| -r.quality }
  end

  def construct_possible_teams(starting_players, players_per_team)
    return to_enum(:construct_possible_teams, starting_players, players_per_team) unless block_given?

    starting_players.combination(players_per_team).each do |team1|
      remaining_players = starting_players - team1

      if remaining_players.size == players_per_team
        yield Set.new([team1, remaining_players])
      else
        construct_possible_teams(remaining_players, players_per_team) do |other_teams|
          yield Set.new([team1, *other_teams.to_a])
        end
      end
    end
  end

  private def format(value)
    if value.is_a?(Numeric) && value.finite?
      value.to_s
    elsif value.is_a?(Numeric)
      "N/A"
    else
      value.to_s
    end
  end

  private def display(output, header: true)
    columns = output.map(&:size).max
    column_sizes = (0...columns).map do |column|
      biggest = output.max_by { |row| row[column].to_s.size }
      [column, format(biggest[column]).size]
    end

    column_sizes = column_sizes.to_h

    output.each_with_index do |row, row_index|
      row.each_with_index do |value, col_index|
        value = if value.is_a?(Numeric) && value.finite?
          format(value).rjust(column_sizes[col_index])
        elsif value.is_a?(Numeric)
          format(value).rjust(column_sizes[col_index])
        else
          format(value).ljust(column_sizes[col_index])
        end

        print(value)
        print(SPACER)
      end
      print("\n")

      if header && row_index == 0
        columns.times do |col_index|
          print('-' * column_sizes[col_index])
          print(SPACER)
        end
        print("\n")
      end
    end
  end

  private def calculate_new_ratings(teams)
    team_ratings = teams.map { |players| build_team(players) }
    rankings = (1..teams.size).to_a
    winners = teams[0]

    results = TrueSkill::FactorGraphTrueSkillCalculator.calculate_new_ratings(
      game_info, 
      team_ratings, 
      rankings
    )

    results.each do |player_name, rating|
      player_rating[player_name].rating = rating
      player_rating[player_name].games_played += 1

      if winners.include?(player_name)
        player_rating[player_name].games_won += 1
      end
    end
  end

  private def build_team(players)
    ratings = players.map do |player_name|
      rating = player_rating[player_name].rating
      [player_name, rating]
    end

    ratings.to_h
  end

  private def player_rating
    @player_rating ||= Hash.new do |hash, player_name|
      hash[player_name] = Player.new(player_name)
    end
  end
end