# Monkey patch for Ruby 4.0 compatibility
# Liquid 4.x uses tainted? which was removed in Ruby 4.0
if RUBY_VERSION >= "4.0"
  module Liquid
    class Variable
      def taint_check(obj)
        # tainted? was removed in Ruby 4.0, so we skip the check
        return
      end
    end
  end
end

