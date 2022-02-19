tenant_email = ['hari.krishnamachari@nestaway.com']
booking_types = ['Bed']
booking_ids = ["197227"]
move_in_date = Date.parse('2022-03-07')
comment = 'Booking is done as per case  2/11/2022 16:22:49'
user_not_exist_emails = []
active_tenants = []
bed_not_available_to_book = []

def booking_creation th,user
  params = {}
  params[:house_id] = th.house_id
  params[:created_by] = 638891
  params[:bookie_id] = user.id
  params[:bookie_type] = 'User'
  params[:booking_type] = 'New'
  params[:booker_id] = th.bed_id
  params[:booker_type] = th.bed_type
  params[:license_start_date] = th.move_in_date
  params[:tenant_type] = th.tenant_type
  params[:status] = 'SUCCESS'
  house=House.find params[:house_id]
  params[:move_in_am_id] = house.area_manager_id
  params[:actual_move_in_date] = th.actual_move_in_date

  booking=Booking.create(params)
  booking.entity_type = "BookingsService::Strategy::Webapp"
  booking.save!
  booking
end

def find_house_id bed_id,booking_type
  if booking_type == 'house'.capitalize
    house = House.find bed_id
    return house
  elsif booking_type == 'bed'.capitalize
    bed = Bed.find bed_id
    return bed.house
  else
    room = Room.find bed_id
    return room.house
  end
end


ActiveRecord::Base.transaction do
 tenant_email.each_with_index do |email,id|
   user = User.find_by_email tenant_email
   if user.nil?
     puts "User #{email} not exist" 
     user_not_exist_emails << email
     next
   end
   profile = user.profile
   tenancy_history = TenancyHistory.where(:profile_id => profile.id).last

   if !tenancy_history.nil? && tenancy_history.active?
     puts '#{email} is active tenant no need to reassign bed'
     active_tenants << email
     next
   else
   	  active_tenancy_history = TenancyHistory.where(:bed_type => booking_types[id],:bed_id => booking_ids[id]).last
   	  if !active_tenancy_history.nil? && active_tenancy_history.active?
   	  	puts "#{booking_types[id]} #{booking_ids[id]} is booked by another tenant"
        bed_not_available_to_book << email
   	  	next
   	  else
        house = find_house_id booking_ids[id].to_i,booking_types[id].capitalize
        "#{booking_types[id].capitalize}Booker".constantize.book(booking_ids[id], profile.id, move_in_date, tenant_type: house.tenant_type,comment: comment)
        new_th = TenancyHistory.where(:profile_id => profile.id).last
        booking = booking_creation new_th,user
        new_th.booking_id = booking.id
        new_th.save!
        ScheduleVisit.cancel_future_sav(profile.id, new_th.house_id)
        invoice_id = PU.new_invoice_id(new_th.profile_id)
        percentage = 0.25
        token_amount = ((percentage * new_th.rent.to_f) / 100.0).ceil * 100.0
        token = new_th.create_receivable(amount: token_amount, reason: 'TOKEN', type: 'RECEIVABLE', due_date: Time.zone.today + 5.days, invoice_id: invoice_id)
        PU.create_advance_firstRent_receivables(new_th.profile_id, new_th.bed_id, Time.zone.today + 5.days,
                                                token_amount, new_th.bed_type, new_th,
                                                { create_sd: true, create_rent: true, create_onboarding_charges: true, create_society_charges: true },
                                                invoice_id)
      end
   end
 end
end
