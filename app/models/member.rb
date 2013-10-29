# == Schema Information
#
# Table name: members
#
#  id             :integer          not null, primary key
#  provider       :string(255)
#  uid            :string(255)
#  name           :string(255)
#  remember_token :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  old_member_id  :integer
#

# == Description
#
# A member of the Portal
#
# == Fields
# - provider: the authorization provider
# - uid: ID of member for the provider
# - name: name of member
# - remember_token: session token
#
# == Associations
#
# === Belongs to:
# - OldMember
#
# === Has Many:
# - CommitteeMember
# - Committee
# - TablingSlotMember
# - TablingSlot
# - Commitment
# - CommitmentCalendar
# - EventMember
# - Reimbursement
class Member < ActiveRecord::Base
  attr_accessible :name, :provider, :uid

  validates :provider, :uid, :name, presence: true

  before_create :create_remember_token

  has_many :tabling_slot_members, dependent: :destroy
  has_many :tabling_slots, through: :tabling_slot_members

  has_many :committee_members, dependent: :destroy
  has_many :committees, through: :committee_members

  has_many :commitment_calendars, dependent: :destroy

  has_many :event_members, dependent: :destroy

  has_many :reimbursements, dependent: :destroy

  has_many :commitments, dependent: :destroy

  has_many :points, dependent: :destroy

  belongs_to :old_member

  # TODO: store in DB
  def primary_committee
    self.committees.first
  end

  # Position of the member.
  # If no committee is given, returns the position for its #primary_committee.
  # Returns nil if the member does not belong to the committee, or it does not have a committee.
  #
  # === Parameters
  # - committee: the Committee to look up the position under; defaults to #primary_committee
  def position(committee=self.primary_committee)
    if committee
      committee_member = self.committee_members.where(
        committee_id: committee.id
      ).first

      committee_member.committee_member_type.name if committee_member
    end
  end

  # Tier of the member
  # If no committee is given, returns the tier for its #primary_committee.
  # Returns nil if the member does not belong to the committee, or it does not have a committee.
  #
  # === Parameters
  # - committee: the Committee to look up the tier under; defaults to #primary_committee
  def tier(committee=primary_committee)
    if committee
      committee_member = self.committee_members.where(
        committee_id: committee.id
      ).first

      committee_member.committee_member_type.tier if committee_member
    end
  end

  # Admin status of the member.
  def admin?
    self.name == "Keien Ohta" or self.committees.include?(Committee.where(name: "Executive").first)
  end

  # Officer status of the member.
  def officer?
    self.admin? or
    self.position == "chair"
  end

  # Returns the relationships between itself and a given TablingSlot.
  #
  # === Parameters
  # - tabling_slot: a TablingSlot
  def tabling_slot_member(tabling_slot)
    self.tabling_slot_members.where(tabling_slot_id: tabling_slot.id).first
  end

  # Ininialize itself with some OmniAuth information
  #
  # === Parameters
  # - provider: the authentication service provider
  # - uid: the ID of the member under the provider
  def self.initialize_with_omniauth(provider, uid)
    Member.where(provider: provider, uid: uid).first_or_initialize
  end

  # The other Members that are part of this member's committees
  def cms
    self.committees.map do |committee|
      committee.members
    end.flatten
  end

  # Create a new session token.
  def Member.new_remember_token
    SecureRandom.urlsafe_base64
  end

  # Encrypt the token.
  def Member.encrypt(token)
    Digest::SHA1.hexdigest(token.to_s)
  end

  # Checks attendance for an event.
  #
  # === Parameters
  # - event: an event with an id
  def attended?(event)
    !self.event_members.where(event_id: event.id).empty?
  end

  # Helper for displaying itself in autocomplete forms.
  def autocomplete_display
    committee_name = self.committees.first ? self.committees.first.name : "N/A"

    "#{self.name}; #{committee_name}: #{self.position || "Member"}"
  end

  # Find matches on the main site using last name and email
  def find_old_members
    old_members = OldMember.where(
      "lower(last_name) = :last_name",
      last_name: self.name.split[-1].downcase,
    )

    return old_members
  end

  # Update member information through the main site
  def update_from_old_member
    if self.old_member
      old_member = self.old_member

      # If this member is a committee member
      if old_member.tier_id == 3

        name = old_member.position.chomp("Committee Member").strip
        committee_type = CommitteeType.committee
        cm_type = CommitteeMemberType.cm

      # If this member is a committee chair
      elsif old_member.tier_id == 4

        name = old_member.position.chomp("Chair").strip
        committee_type = CommitteeType.committee
        cm_type = CommitteeMemberType.chair

      # If this member is an executive
      elsif old_member.tier_id == 5

        name = "Executive"
        committee_type = CommitteeType.admin
        cm_type = CommitteeMemberType.exec(old_member.position)

        # Exit with nil if the correct cm_type was not found
        return nil if cm_type.nil?

      # If this member is a general member
      elsif old_member.tier_id == 2

        name = "General Members"
        committee_type = CommitteeType.general
        cm_type = CommitteeMemberType.gm

      end

      self.add_to_committee(name, committee_type, cm_type)

      # Remove from any general committees unless the member belongs there
      self.remove_from_general unless old_member.tier_id == 2

      return self.save
    end
  end


  # Add member to the committee (creating the committee if it doesn't exist) as the given
  # committee member type, if he isn't part of the committee already
  def add_to_committee(committee_name, committee_type, cm_type)
    # Find or create committee
    committee = Committee.where(
      name: committee_name,
    ).first_or_create!

    # Set the committee type
    committee.committee_type = committee_type
    committee.save!

    # Add member to committee if not already
    committee_member = self.committee_members.where(
      committee_id: committee.id,
    ).first_or_create!

    # Set the committee_member type
    committee_member.committee_member_type = cm_type
    committee_member.save!
  end

  # Remove from the general committee, if put in a regular committee.
  # Done by default when adding to a regular committee.
  def remove_from_general
    # Get general committees (may be more than one)
    general = Committee.where(
      committee_type_id: CommitteeType.general.id
    )

    # If this member is in the general members group (tested using set difference)
    if (general - self.committees).empty?
      general.each do |committee|
        self.committees.delete(general)
      end
    end
  end

  # Calculate the total number of points this member has
  def total_points
    sum = 0

    # Calculate points from events
    self.event_members.each do |event_member|
      sum += event_member.event_points.value
    end

    # Calculate points from tabling
    self.tabling_slot_members.where(
      status_id: Status.where(name: :attended).first
    ).each do |tsm|
      sum += TablingSlot::POINTS
    end

    return sum
  end

  # Return all attended tabling slots
  def attended_slots
    self.tabling_slot_members.where(status_id: Status.where(name: :attended).first).map do |tsm|
      tsm.tabling_slot
    end
  end

  private

    def create_remember_token
      self.remember_token = Member.encrypt(Member.new_remember_token)
    end

end
