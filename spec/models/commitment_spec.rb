# == Schema Information
#
# Table name: commitments
#
#  id         :integer          not null, primary key
#  member_id  :integer
#  summary    :string(255)
#  start_time :datetime
#  end_time   :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require 'spec_helper'

describe Commitment do
  pending "add some examples to (or delete) #{__FILE__}"
end
