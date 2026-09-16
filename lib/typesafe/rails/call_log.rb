# frozen_string_literal: true

module Typesafe
  module Rails
    class CallLog < ActiveRecord::Base
      self.table_name = "typesafe_calls"
    end
  end
end
