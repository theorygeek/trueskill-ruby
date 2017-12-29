module TrueSkill
  class GaussianFactor
    attr_accessor :messages, :message_to_variable_binding, :name, :variables

    def initialize(name)
      self.name = "Factor[#{name}]"
      self.messages = []
      self.variables = []
      self.message_to_variable_binding = {}
    end

    def log_normalization
      0.to_f
    end

    def update_message!(index)
      update_message_core!(messages[index], message_to_variable_binding[messages[index]])
    end

    def update_message_core!(message, variable)
      raise "NotImplementedError #{self.class.name}"
    end

    def reset_marginals!
      message_to_variable_binding.each_value(&:reset_to_prior!)
    end

    def send_message!(index)
      send_message_core!(messages[index], message_to_variable_binding[messages[index]])
    end

    def send_message_core!(message, variable)
      marginal = variable.value
      message_value = message.value

      log_z = GaussianDistribution.log_product_normalization(marginal, message_value)
      variable.value = marginal * message_value
      log_z
    end

    def create_variable_to_message_binding(variable, message = nil)
      message ||= Message.new(GaussianDistribution.from_precision_mean(0, 0), "message from #{self} to #{variable}")

      messages << message
      variables << variable
      message_to_variable_binding[message] = variable
      
      message
    end

    class WeightedSum < GaussianFactor
      attr_accessor :variable_index_orders_for_weights, :weights, :weights_squared

      def initialize(sum_variable, variables_to_sum, variable_weights = nil)
        variable_weights ||= Array.new(variables_to_sum.size) { 1.0 }
        super(WeightedSum.create_name(sum_variable, variables_to_sum, variable_weights))
        self.variable_index_orders_for_weights = []
        self.weights = Array.new(variable_weights.count + 1) { [] }
        self.weights_squared = Array.new(weights.count) { [] }

        # The first weights are a straightforward copy
        # v_0 = a_1*v_1 + a_2*v_2 + ... + a_n * v_n
        weights[0] = variable_weights.dup
        weights_squared[0] = weights[0].map { |w| w ** 2 }

        # 0..n-1
        variable_index_orders_for_weights << (0..variables_to_sum.count).to_a

        # The rest move the variables around and divide out the constant. 
        # For example:
        # v_1 = (-a_2 / a_1) * v_2 + (-a3/a1) * v_3 + ... + (1.0 / a_1) * v_0
        # By convention, we'll put the v_0 term at the end

        (1...weights.count).each do |weights_index|
          current_weights = Array.new(variable_weights.count) { 0.0 }
          weights[weights_index] = current_weights

          variable_indices = Array.new(variable_weights.count + 1) { 0 }
          variable_indices[0] = weights_index

          current_weights_squared = Array.new(variable_weights.count) { 0.0 }
          weights_squared[weights_index] = current_weights_squared

          # keep a single variable to keep track of where we are in the array.
          # This is helpful since we skip over one of the spots
          current_destination_weight_index = 0

          (0...variable_weights.count).each do |current_weight_source_index|
            next if current_weight_source_index == (weights_index - 1)
            current_weight = (-variable_weights[current_weight_source_index] / variable_weights[weights_index - 1])

            # HACK: Getting around division by zero
            current_weight = 0.0 if variable_weights[weights_index - 1] == 0
            current_weights[current_destination_weight_index] = current_weight
            current_weights_squared[current_destination_weight_index] = current_weight ** 2

            variable_indices[current_destination_weight_index + 1] = current_weight_source_index + 1
            current_destination_weight_index += 1
          end

          # And the final one
          final_weight = 1.0 / variable_weights[weights_index - 1]

          # HACK: Getting around division by zero
          final_weight = 0.0 if variable_weights[weights_index - 1] == 0
          
          current_weights[current_destination_weight_index] = final_weight
          current_weights_squared[current_destination_weight_index] = final_weight ** 2
          variable_indices[variable_indices.count - 1] = 0
          variable_index_orders_for_weights << variable_indices
        end

        create_variable_to_message_binding(sum_variable)

        variables_to_sum.each do |current_variable|
          create_variable_to_message_binding(current_variable)
        end
      end

      def log_normalization
        result = 0.0

        (1...variables.count).each do |i|
          result += GaussianDistribution.log_ratio_normalization(variables[i].value, messages[i].value)
        end
        
        result
      end

      def update_helper(weights, weights_squared, messages, variables)
        # Potentially look at http:#mathworld.wolfram.com/NormalSumDistribution.html for clues as 
        # to what it's doing

        message0 = messages[0].value.dup
        marginal0 = variables[0].value.dup

        # The math works out so that 1/new_precision = sum of a_i^2 /marginalsWithoutMessages[i]
        inverse_of_new_precision_sum = 0.0
        another_inverse_of_new_precision_sum = 0.0
        weighted_mean_sum = 0.0
        another_weighted_mean_sum = 0.0

        (0...weights_squared.count).each do |i|
          # These flow directly from the paper

          inverse_of_new_precision_sum += weights_squared[i] / (variables[i + 1].value.precision - messages[i + 1].value.precision)

          diff = variables[i + 1].value / messages[i + 1].value
          another_inverse_of_new_precision_sum += weights_squared[i] / diff.precision
          weighted_mean_sum += weights[i] * (variables[i + 1].value.precision_mean - messages[i + 1].value.precision_mean) / (variables[i + 1].value.precision - messages[i + 1].value.precision)
          another_weighted_mean_sum += weights[i] * diff.precision_mean / diff.precision
        end

        new_precision = 1.0 / inverse_of_new_precision_sum
        another_new_precision = 1.0 / another_inverse_of_new_precision_sum

        new_precision_mean = new_precision * weighted_mean_sum
        another_new_precision_mean = another_new_precision * another_weighted_mean_sum

        new_message = GaussianDistribution.from_precision_mean(new_precision_mean, new_precision)
        old_marginal_without_message = marginal0 / message0

        new_marginal = old_marginal_without_message * new_message

        #/ Update the message and marginal

        messages[0].value = new_message
        variables[0].value = new_marginal

        #/ Return the difference in the new marginal
        new_marginal - marginal0
      end

      def update_message!(message_index)
        updated_messages = []
        updated_variables = []

        indices_to_use = variable_index_orders_for_weights[message_index]

        # The tricky part here is that we have to put the messages and variables in the same
        # order as the weights. Thankfully, the weights and messages share the same index numbers,
        # so we just need to make sure they're consistent
        (0...messages.count).each do |i|
          updated_messages << messages[indices_to_use[i]]
          updated_variables << variables[indices_to_use[i]]
        end
        
        update_helper(weights[message_index], weights_squared[message_index], updated_messages, updated_variables)
      end

      def self.create_name(sum_variable, variables_to_sum, weights)
        sb = String.new
        sb << sum_variable.to_s
        sb << ' = '

        (0...variables_to_sum.count).each do |i|
          is_first = (i == 0)
          sb << "-" if (is_first && (weights[i] < 0))
          sb << weights[i].abs.to_s
          sb << "*["
          sb << variables_to_sum[i].to_s
          sb << "]"

          is_last = (i == variables_to_sum.count - 1)
          next if is_last

          if weights[i + 1] >= 0
            sb << " + "
          else
            sb << " - "
          end
        end

        sb.freeze
      end
    end

    class Prior < GaussianFactor
      attr_accessor :new_message

      def initialize(mean, variance, variable)
        super("Prior value going to #{variable}")

        self.new_message = GaussianDistribution.new(mean, Math.sqrt(variance))
        
        create_variable_to_message_binding(
          variable, 
          Message.new(GaussianDistribution.from_precision_mean(0, 0), "message from #{self} to #{variable}")
        )
      end

      def update_message_core!(message, variable)
        old_marginal = variable.value.dup
        old_message = message
        new_marginal = GaussianDistribution.from_precision_mean(
          old_marginal.precision_mean + new_message.precision_mean - old_message.value.precision_mean,
          old_marginal.precision + new_message.precision - old_message.value.precision
        )

        variable.value = new_marginal
        message.value = new_message
        
        old_marginal - new_marginal
      end
    end

    class Likelihood < GaussianFactor
      attr_accessor :precision

      def initialize(beta_squared, variable1, variable2)
        super("Likelihood of #{variable2} going to #{variable1}")
        self.precision = 1.0 / beta_squared

        create_variable_to_message_binding(variable1)
        create_variable_to_message_binding(variable2)
      end
      
      def log_normalization
        GaussianDistribution.log_ratio_normalization(variables[0].value, messages[0].value)
      end
      
      def update_helper(message1, message2, variable1, variable2)
        message1_value = message1.value.dup
        message2_value = message2.value.dup
    
        marginal1 = variable1.value.dup
        marginal2 = variable2.value.dup
    
        a = precision / (precision + marginal2.precision - message2_value.precision)
    
        new_message = GaussianDistribution.from_precision_mean(
          a * (marginal2.precision_mean - message2_value.precision_mean),
          a * (marginal2.precision - message2_value.precision)
        )
    
        old_marginal_without_message = marginal1 / message1_value
    
        new_marginal = old_marginal_without_message * new_message
    
        # Update the message and marginal
        message1.value = new_message
        variable1.value = new_marginal
    
        # Return the difference in the new marginal
        new_marginal - marginal1
      end
      
      def update_message!(message_index)
        case message_index
        when 0
          update_helper(messages[0], messages[1], variables[0], variables[1])
        when 1
          update_helper(messages[1], messages[0], variables[1], variables[0])
        else
          raise "ArgumentOutOfRangeException"
        end
      end
    end

    class Within < GaussianFactor
      attr_accessor :epsilon

      def initialize(epsilon, variable)
        super("#{variable} <= #{'%.3f' % epsilon}")
        self.epsilon = epsilon
        create_variable_to_message_binding(variable)
      end
      
      def log_normalization
        marginal = variables[0].value
        message = messages[0].value
        message_from_variable = marginal / message

        mean = message_from_variable.mean
        std = message_from_variable.standard_deviation
        z = GaussianDistribution.cumulative_to((epsilon - mean) / std) - GaussianDistribution.cumulative_to((-epsilon - mean) / std)
        -GaussianDistribution.log_product_normalization(message_from_variable, message) + Math.log(z)
      end
      
      def update_message_core!(message, variable)
        old_marginal = variable.value.dup
        old_message = message.value.dup
        message_from_variable = old_marginal / old_message
    
        c = message_from_variable.precision
        d = message_from_variable.precision_mean
    
        sqrt_c = Math.sqrt(c)
        d_on_sqrt_c = d / sqrt_c
    
        epsilon_times_sqrt_c = epsilon * sqrt_c
        d = message_from_variable.precision_mean
    
        denominator = 1.0 - TruncatedGaussianCorrectionFunctions.w_within_margin(d_on_sqrt_c, epsilon_times_sqrt_c)
        new_precision = c / denominator
        new_precision_mean = (d + sqrt_c * TruncatedGaussianCorrectionFunctions.v_within_margin(d_on_sqrt_c, epsilon_times_sqrt_c)) / denominator

        new_marginal = GaussianDistribution.from_precision_mean(new_precision_mean, new_precision)
        new_message = old_message * new_marginal / old_marginal
    
        # Update the message and marginal
        message.value = new_message
        variable.value = new_marginal
    
        # Return the difference in the new marginal
        new_marginal - old_marginal
      end  
    end

    class GreaterThan < GaussianFactor
      attr_accessor :epsilon

      def initialize(epsilon, variable)
        super("#{variable} > #{epsilon ? '%.3f' % epsilon : 'nil'}")
        self.epsilon = epsilon
        create_variable_to_message_binding(variable)
      end
      
      def log_normalization
        marginal = variables[0].value
        message = messages[0].value
        message_from_variable = marginal / message
        -GaussianDistribution.log_product_normalization(message_from_variable, message) + Math.log(GaussianDistribution.cumulative_to((message_from_variable.mean - epsilon) / message_from_variable.standard_deviation))
      end
      
      def update_message_core!(message, variable)
        old_marginal = variable.value.dup
        old_message = message.value.dup
        message_from_var = old_marginal / old_message
    
        c = message_from_var.precision
        d = message_from_var.precision_mean
    
        sqrt_c = Math.sqrt(c)
        d_on_sqrt_c = d / sqrt_c
    
        epsilson_times_sqrt_c = epsilon * sqrt_c
        d = message_from_var.precision_mean
        denom = 1.0 - TruncatedGaussianCorrectionFunctions.w_exceeds_margin(d_on_sqrt_c, epsilson_times_sqrt_c)
    
        new_precision = c/denom
        new_precision_mean = (d + sqrt_c * TruncatedGaussianCorrectionFunctions.v_exceeds_margin(d_on_sqrt_c, epsilson_times_sqrt_c)) / denom
        new_marginal = GaussianDistribution.from_precision_mean(new_precision_mean, new_precision)
        newMessage = old_message * new_marginal / old_marginal
    
        # Update the message and marginal
        message.value = newMessage
        variable.value = new_marginal
    
        # Return the difference in the new marginal
        new_marginal - old_marginal
      end
    end
  end
end