u = User.find_by_email 'srivastavraashi22@gmail.com'
p = u.profile
th = TenancyHistory.where(:profile_id => p.id).last

params = {}
params[:house_id] = th.house_id
params[:created_by] = 638891
params[:bookie_id] = u.id
params[:bookie_type] = 'User'
params[:booking_type] = 'INTERNAL_TRANSFER_CANCEL'
params[:booker_id] = th.bed_id
params[:booker_type] = th.bed_type
params[:license_start_date] = th.move_in_date
params[:tenant_type] = th.tenant_type
params[:status] = 'SUCCESS'
h=House.find params[:house_id]
params[:move_in_am_id] = h.area_manager_id
params[:actual_move_in_date] = th.actual_move_in_date

booking=Booking.new(params)
booking.entity_type = "BookingsService::Strategy::Webapp"
booking.save!

th.booking = booking
th.booking_id = booking.id
th.save!


def build(params)
  booking = self.new params.to_hash.symbolize_keys.slice(:house_id, :created_by, :bookie_id, :bookie_type)
  booking.booking_type = params[:booking_type] || 'New'
  booking.booker_id = params[:bed_id].to_i if params.has_key?(:bed_id)
  booking.booker_type = params[:bed_type].try(:capitalize) || Bed.to_s
  booking.license_start_date = Date.parse(params[:move_in_date]) if params.has_key?(:move_in_date)
  booking.referrer_id = params[:referrer_id] if params.has_key?(:referrer_id)
  booking.coupon_id = params[:coupon_id] if params.has_key?(:coupon_id)
  booking.tenant_type = params[:tenant_type]
  booking.device = get_device_info(params)
  booking.status = params[:status] || 'New'
  booking.move_in_am_id = params[:move_in_am_id]
  booking.am_id = params[:am_id]
  if params[:actual_move_in_date].present?
    booking.actual_move_in_date = Time.zone.parse("#{params[:actual_move_in_date]} "\
                                                  "#{params[:actual_move_in_time]}")
  end
  booking.more_data = {}
  booking.strategy = params[:strategy] || BookingsService::Strategy::Webapp.name

  booking.send("#{booking.booking_type.downcase}_initialize", params)
  booking
end



emails = ["batra.richa31@gmail.com"]
succ = []
failed = []
no_book = []
ActiveRecord::Base.transaction do
emails.each do|e|
user = User.find_by_email(e)
th = TenancyHistory.where(:profile_id => user.profile.id).last
book = Booking.where(:bookie_id => user.id).last

if(book.nil?)
no_book << e
elsif (book.booker_id == th.bed_id && book.booker_type == th.bed_type && th.booking_id != nil && book.entity_type != nil)
  succ << e
else
failed << e
next if (th.booking_id != nil)
book = Booking.new
book.booking_type = "INTERNAL_TRANSFER"
book.status = "New"
book.booker_id = th.bed_id
book.booker_type = th.bed_type
book.bookie_id = user.move_in_date
book.bookie_type = "User"
book.house_id = th.house_id
book.license_start_date = th.move_in_date
book.actual_move_in_date = th.actual_move_in_date
book.tenant_type = th.tenant_type
book.entity_type = "BookingsService::Strategy::Webapp"
book.save!

th.booking_id = book.id
th.save!
end
end
end