class TablingSlotsController < ApplicationController

  before_filter :admin_member, only: [ :generate, :add_to_google_calendar ]

  def index
    @prev = params[:prev].to_i

    @tabling_slots = TablingSlot.where(
      "start_time >= :tabling_start and start_time <= :tabling_end",
      tabling_start: tabling_start + @prev.weeks,
      tabling_end: tabling_end + @prev.weeks,
    ).order(:start_time)

    if !@tabling_slots.empty?
      @earliest_time = @tabling_slots.first.start_time

      @tabling_days = Hash.new
      @tabling_slots.each do |tabling_slot|
        @tabling_days[tabling_slot.start_time.to_date] ||= Array.new
        tabling_day = @tabling_days[tabling_slot.start_time.to_date]

        tabling_day << tabling_slot
      end
    end

    # NOTE: change to right ID
    @members_calendar_id = "pjnj2vfdlcui8n9244teaekvds@group.calendar.google.com"
  end

  def print
    @tabling_slots = TablingSlot.where(
      "start_time >= :tabling_start and start_time <= :tabling_end",
      tabling_start: tabling_start,
      tabling_end: tabling_end,
    ).order(:start_time)

    if !@tabling_slots.empty?
      @earliest_time = @tabling_slots.first.start_time

      @tabling_days = Hash.new
      @tabling_slots.each do |tabling_slot|
        @tabling_days[tabling_slot.start_time.to_date] ||= Array.new
        tabling_day = @tabling_days[tabling_slot.start_time.to_date]

        tabling_day << tabling_slot
      end
    end

    render layout: "print"
  end

  def show
    @tabling_slot = TablingSlot.find(params[:id])
    @tabling_slot_member = TablingSlotMember.new
  end

  def generate
    if DateTime.now.cwday > 5 # If later than Friday
      write_init_files
      if generate_schedule
        redirect_to tabling_slots_path
      else
        redirect_to tabling_slots_path, notice: "Tabling generation has failed. Try running 'heroku restart --app ucbpblmembersportal' to refresh the Java objects and try again."
      end
    else
      redirect_to tabling_slots_path, notice: "You cannot do that until after Friday"
    end
  end

  def add_to_google_calendar
    @members_calendar_id = "pjnj2vfdlcui8n9244teaekvds@group.calendar.google.com"
    @tabling_slots = TablingSlot.order(:start_time)

    @tabling_slots.each do |tabling_slot|
      event = {
        start: { dateTime: tabling_slot.start_time },
        end: { dateTime: tabling_slot.end_time },
        summary: "Tabling for #{tabling_slot.members.map {|m| m.name}.to_sentence}",
      }
      result = google_api_request(
        'calendar', 'v3', 'events', 'insert',
        { calendarId: @members_calendar_id },
        JSON.dump(event)
      )
    end
  end

  def tabling_options
    @all_slots = TablingSlot.all

    # this shows all the tabling slots
    # TODO only show the tabling slots you have generated for this week/the ones you will overwrite
    @tabling_days = Hash.new
    if !@all_slots.empty?
      @earliest_time = @all_slots.first.start_time

      @tabling_days = Hash.new
      @all_slots.each do |tabling_slot|
        @tabling_days[tabling_slot.start_time.to_date] ||= Array.new
        tabling_day = @tabling_days[tabling_slot.start_time.to_date]
        tabling_day << tabling_slot
      end
    end
  end

  def generate_tabling
    puts "about to generate tabling slots"
    timeslots = params[:slots]
    puts timeslots
    puts "THAT WAS TIMESLOTS"
    @slots = Array.new
    # TODO: destroy all tablings slots?
    # should only destroy all tabling slots for this week
    # TablingSlot.destroy_all
    clear_this_week_slots
    timeslots.keys.each do |key|
      day = Date::DAYNAMES[key.to_i]
      if timeslots[key].length > 0
        timeslots[key].each do |h|
          hour = h.to_i
          @slots << TablingSlot.where(
            start_time: Chronic.parse("#{hour} this #{day}"),
            end_time: Chronic.parse("#{hour + 1} this #{day}")
          ).first_or_create!
        end
      end
    end
    generate_tabling_schedule(@slots)
    render json: "your thing worked and i added tabling slots for you homie"
  end

  # helper methods for tabling generation
  def clear_this_week_slots
    days = (0..7).to_a
    hours = (1..24).to_a
    days.each do |key|
      day = Date::DAYNAMES[key]
      hours.each do |hour|
        TablingSlot.where(
          start_time: Chronic.parse("#{hour} this #{day}"),
          end_time: Chronic.parse("#{hour + 1} this #{day}")
        ).destroy_all
      end
    end
  end

# input slots: tabling slots that you want to fill
# return assignments hash key: slot, value: array of members}
  def generate_tabling_schedule(slots)
    puts "generating schedule"
    #initialize your assignment hash
    assignments = Hash.new
    assignments["manual"] = Array.new
    manual_assignments = Array.new
    for s in slots
      assignments[s] = Array.new
    end
    curr_member = get_MCV(assignments)
    while curr_member != nil do
      puts "assigning"
      puts curr_member
      slot = get_LCV(assignments, curr_member)
      if slot != nil
        # assign student to the slot
        assignments[slot] << curr_member
      else
        # you cant assign this member
        manual_assignments << curr_member
        assignments["manual"] << curr_member
      end
      curr_member = get_MCV(assignments)
    end
    save_tabling_results(assignments, slots)
    return assignments
  end

  # return the hardest to work with member (least slots open)
  def get_MCV(assignments)
    difficult_members = Array.new
    num_slots = 1000
    for member in Member.all
      if not is_assigned(assignments, member)
        available_slots = get_current_available_slots(assignments, member).length
        if available_slots < num_slots
          difficult_members = Array.new
          difficult_members << member
          num_slots = available_slots
        elsif available_slots == num_slots
          difficult_members << member
        end
      end
    end
    # should be random?
    # TODO: backtracking
    return difficult_members.sample
  end

  # least constrained value
  # slot with highest capacity after member has been assigned
  def get_LCV(assignments, member)
    max_capacity = -1;
    lcv_slots = Array.new
    slots = get_current_available_slots(assignments,member)
    for slot in slots
      remaining_capacity = 5000-assignments[slot].length
      if remaining_capacity > max_capacity
        lcv_slots = Array.new
        max_capacity = remaining_capacity
        lcv_slots << slot
      elsif remaining_capacity == max_capacity
        lcv_slots << slot
      end
    end
    return lcv_slots.sample
  end

  # returns if start1, end1, conflicts with start2, end2
  def conflicts(s1,e1,s2,e2)
    if s1<=s2 and e1>s2
      return true
    elsif s1<e2 and s1>s2
      return true
    end
    return false
  end

  # return if member has been assigned
  def is_assigned(assignments, member)
      for key in assignments.keys
        list = assignments[key]
        if list.include? member
          return true
        end
      end
      return false
    end
  end

   # assumes each slot has same capacity 5
  # TODO add capacity to tabling_slots table
  def get_current_available_slots(assignments, member)
    slots = Array.new
    assignments.keys.each do |key|
      slot = key
      conflicts = true
      if not slot == "manual"
        conflicts = false
        for c in member.commitments
          d = c.day
          s = c.start_hour
          e = c.end_hour
          if d
            day = Date::DAYNAMES[d]
            start = Chronic.parse("#{s} this #{day}")
            endt =  Chronic.parse("#{e} this #{day}")
            if day and conflicts(start, endt, slot.start_time, slot.end_time)
              conflicts = true
              break
            end
          end
        end
      end
      if not conflicts
        if assignments[slot].length < 5000 # hard coded capacity
          slots << slot
        end
      end
    end
    return slots
  end

def save_tabling_results(assignments, slots)
  for tabling_slot in slots
      if tabling_slot
        for member in assignments[tabling_slot]
          slot_member = TablingSlotMember.where(member_id: member.id).where(tabling_slot_id: tabling_slot.id).first
          if slot_member
            puts "THe member is already there"
          else
            slot_member = TablingSlotMember.new
            slot_member.member_id = member.id
            slot_member.tabling_slot_id = tabling_slot.id
            slot_member.save
          end
          if not tabling_slot.members.include? member
            tabling_slot.members << member
          end
        end
      else
        puts "Tabling slot not found"
      end
    end
    # handle the manually assign members
    odd_slot = TablingSlot.new
    # odd_slot.start_time = Date.now
    # odd_slot.end_time = 1
    day = Date::DAYNAMES[6]
    hour = 1
    odd_slot = TablingSlot.where(
          start_time: Chronic.parse("#{hour} this #{day}"),
          end_time: Chronic.parse("#{hour + 1} this #{day}")
        ).first_or_create!
    odd_slot.save
    for member in assignments["manual"]
      slot_member = TablingSlotMember.new
      slot_member.member_id = member.id
      slot_member.tabling_slot_id = odd_slot.id
      slot_member.save
      if not odd_slot.members.include? member
        odd_slot.members << member
      end
    end
end