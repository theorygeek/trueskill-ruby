module TrueSkill
  class FactorList
    attr_accessor :list
    
    def initialize
      self.list = []
    end

    def log_normalization
      list.each { |f| f.reset_marginals! }
      sum_log_z = 0.0
      
      list.each do |f|
        (0...f.messages.count).each do |j|
          sum_log_z += f.send_message!(j)
        end
      end
                      
      sum_log_s = list.reduce(0.0) { |acc, fac| acc + fac.log_normalization }
      sum_log_z + sum_log_s
    end
  end
end