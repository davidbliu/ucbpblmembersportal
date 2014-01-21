# == Schema Information
#
# Table name: event_members
#
#  id         :integer          not null, primary key
#  event_id   :string(255)
#  member_id  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# == Description
#
# A Member attending an event
#
# == Fields
# - event_id: reference to the event
#
# == Associations
#
# === Belongs to:
# - Member
#
# === Has one:
# - EventPoint
class EventMember < ActiveRecord::Base
  attr_accessible :event_id, :member_id, :semester_id, :google_id

  belongs_to :member
  belongs_to :semester, foreign_key: :semester_id
  belongs_to :event, foreign_key: :event_id
  has_one :event_points, foreign_key: :event_id, primary_key: :event_id

  def event
  	if Event.where(id: self.event_id).length != 0
  		return Event.find(self.event_id)
  	else
  		nil
  	end
  end

  def semester
  	if self.event
  		return self.event.semester
  	else
  		return nil
  	end
  end
end
