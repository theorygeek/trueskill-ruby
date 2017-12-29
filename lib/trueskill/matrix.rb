module TrueSkill
  class Matrix
    # Anything smaller than this will be assumed to be rounding error in terms of equality matching
    FRACTIONAL_DIGITS_TO_ROUND_TO = 10
    ERROR_TOLERANCE = 0.1 ** FRACTIONAL_DIGITS_TO_ROUND_TO # e.g. 1/10^10

    attr_accessor :matrix_row_values, :rows, :columns

    def initialize(rows:, columns:, row_values: nil, column_values: nil)
      self.rows = rows
      self.columns = columns

      if row_values
        self.matrix_row_values = Array.new(rows) do |i| 
          Array.new(columns) do |j|
            row_values.dig(i, j)&.to_f || 0.0
          end
        end
      elsif column_values
        self.matrix_row_values = Array.new(rows) do |i| 
          Array.new(columns) do |j|
            column_values.dig(j, i)&.to_f || 0.0
          end
        end
      else
        self.matrix_row_values = Array.new(rows) { Array.new(columns) { 0.0 } }
      end
      
      freeze
      matrix_row_values.freeze
      matrix_row_values.each(&:freeze)
    end

    delegate :[], to: :matrix_row_values

    def transpose
      # Just flip everything
      Matrix.new(rows: columns, columns: rows, column_values: matrix_row_values)
    end

    def is_square
      rows && rows == columns && rows > 0
    end

    def determinant
      # Basic argument checking
      raise "matrix must be square!" unless is_square

      if rows == 1
        # Really happy path :)
        return matrix_row_values[0][0]
      elsif rows == 2
        # Happy path!
        # Given:
        # | a b |
        # | c d |
        # The determinant is ad - bc
        a = matrix_row_values[0][0]
        b = matrix_row_values[0][1]
        c = matrix_row_values[1][0]
        d = matrix_row_values[1][1]
        return a * d - b * c 
      end 

      # I use the Laplace expansion here since it's straightforward to implement.
      # It's O(n^2) and my implementation is especially poor performing, but the
      # core idea is there. Perhaps I should replace it with a better algorithm
      # later.
      # See http:#en.wikipedia.org/wiki/Laplace_expansion for details

      result = 0.0
      
      # I expand along the first row
      (0...columns).each do |current_column|
        first_row_col_value = matrix_row_values[0][current_column]
        cofactor = cofactor(0, current_column)
        itemToAdd = first_row_col_value * cofactor
        result += itemToAdd
      end

      result
    end

    def adjugate
      raise "matrix must be square!" unless is_square

      # See http:#en.wikipedia.org/wiki/Adjugate_matrix
      if (rows == 2)
        # Happy path!
        # Adjugate of:
        # | a b |
        # | c d |
        # is
        # | d -b |
        # | -c a |

        a = matrix_row_values[0][0]
        b = matrix_row_values[0][1]
        c = matrix_row_values[1][0]
        d = matrix_row_values[1][1]
        Square.new(d, -b, -c, a)
      end

      # The idea is that it's the transpose of the cofactors                
      result = Array.new(columns) { Array.new(rows) { 0.0 } }
      (0...columns).each do |current_column|
        (0...rows).each do |current_row|
          result[current_column][current_row] = cofactor(current_row, current_column)
        end
      end

      Matrix.new(rows: columns, columns: rows, row_values: result)
    end

    def inverse
      return Square.new(1.0 / matrix_row_values[0][0]) if ((rows == 1) && (columns == 1))

      # Take the simple approach:
      # http:#en.wikipedia.org/wiki/Cramer%27s_rule#Finding_inverse_matrix
      adjugate * (1.0 / determinant)
    end

    def *(value)
      if value.is_a?(Matrix)
        # Just your standard matrix multiplication.
        # See http:#en.wikipedia.org/wiki/Matrix_multiplication for details
        left = self
        right = value

        raise "The width of the left matrix must match the height of the right matrix" unless left.columns == right.rows
  
        result_rows = left.rows
        result_columns = right.columns
        result_matrix = Array.new(result_rows) { Array.new(result_columns) { 0.0 } }

        (0...result_rows).each do |current_row|
          (0...result_columns).each do |current_column|
            product_value = 0

            (0...left.columns).each do |vector_index|
              left_value = left.matrix_row_values[current_row][vector_index]
              right_value = right.matrix_row_values[vector_index][current_column]
              vector_index_product = left_value * right_value
              product_value += vector_index_product
            end

            result_matrix[current_row][current_column] = product_value
          end
        end

        Matrix.new(rows: result_rows, columns: result_columns, row_values: result_matrix)
      elsif value.is_a?(Numeric)
        value = value.to_f
        new_values = []

        (0...rows).each do |current_row|
          new_row_column_values = Array.new(columns) { 0.0 }
          new_values[current_row] = new_row_column_values

          (0...columns).each do |current_column|
            new_row_column_values[current_column] = value * matrix_row_values[current_row][current_column]
          end
        end

        Matrix.new(rows: rows, columns: columns, row_values: new_values)
      else
        raise ArgumentError, "value must be matrix or numeric"
      end
    end

    def +(right)
      left = self
      raise ArgumentError, "matrices must be of the same size" unless left.rows == right.rows && left.columns == right.columns

      result_matrix = Array.new(left.rows) { Array.new(right.columns) { 0.0 } }
      (0...left.rows).each do |current_row|
        (0...right.columns).each do |current_column|
          result_matrix[current_row][current_column] = left.matrix_row_values[current_row][current_column] + right.matrix_row_values[current_row][current_column]
        end
      end

      Matrix.new(rows: left.rows, columns: right.columns, row_values: result_matrix)
    end

    def minor_matrix(row_to_remove, column_to_remove)
      # See http:#en.wikipedia.org/wiki/Minor_(linear_algebra)
      result = matrix_row_values.map { |row| row.dup }
      result.delete_at(row_to_remove)
      result.each { |row| row.delete_at(column_to_remove) }
      Matrix.new(rows: rows - 1, columns: columns - 1, row_values: result)
    end

    def cofactor(row_to_remove, column_to_remove)
      # See http:#en.wikipedia.org/wiki/Cofactor_(linear_algebra) for details
      # REVIEW: should things be reversed since I'm 0 indexed?
      sum = row_to_remove + column_to_remove
      is_even = (sum % 2 == 0)

      if is_even
        minor_matrix(row_to_remove, column_to_remove).determinant
      else
        -1.0 * minor_matrix(row_to_remove, column_to_remove).determinant
      end
    end

    # Equality stuff
    def ==(other)
      return false unless other.is_a?(Matrix)
      return true if equal?(other)
      return false unless rows == other.rows && columns == other.columns

      (0...rows).each do |i|
        (0...columns).each do |j|
          return false if (self[i][j] - other[i][j]) > ERROR_TOLERANCE
        end
      end

      true
    end

    alias eql? ==

    def hash
      # Really dumb algorithm, just need good-enough
      rows ^ columns
    end

    class Diagonal < Matrix
      def initialize(diagonal_values)
        row_values = Array.new(diagonal_values.count) { Array.new(diagonal_values.count) { 0.0 } }
        diagonal_values.each_with_index do |value, idx|
          row_values[idx][idx] = value
        end

        super(rows: diagonal_values.count, columns: diagonal_values.count, row_values: row_values)
      end
    end

    class Vector < Matrix
      def initialize(values)
        super(rows: values.count, columns: 1, column_values: [values])
      end
    end

    class Square < Matrix
      def initialize(*values)
        rows = Math.sqrt(values.count).to_i

        matrix_row_values = Array.new(rows) do |i|
          Array.new(rows) do |j|
            values[i * rows + j]
          end
        end

        super(rows: rows, columns: rows, row_values: matrix_row_values)
      end
    end

    class Identity < Diagonal
      def initialize(number_rows)
        result = Array.new(number_rows) { 1.0 }
        super(result)
      end
    end
  end
end