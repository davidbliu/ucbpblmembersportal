class Semester < ActiveRecord::Base
  attr_accessible :end_date, :name, :start_date
  has_many :members, through: :semester_members
  has_many :event_points
  has_many :committee_members
  has_many :events
  has_many :event_members

  def self.current_semester
  	# return Semester.first(:order => 'created_at DESC')
  	return Semester.first
  end
end
