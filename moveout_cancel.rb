tenant_emails = ['toshniwal_sneha@yahoo.in']
user_not_exist = []
case_id = '2/26/2022 15:45:41'
notes = "Tenant wants to stay with Nestaway home,hence move out has been revoked as per case #{case_id}"
no_mo_request_present = []

ActiveRecord::Base.transaction do
 tenant_emails.each_with_index do |email,index|
   user = User.find_by_email email
   if user.nil?
      user_not_exist << email
      next
   end

   profile = user.profile

   tenancy_history = TenancyHistory.where(:profile_id => profile.id).last
   if !tenancy_history.active?
      moved_out_tenants << email  #Bed already released
      next
   end

   mo_move_request = MoveRequest.where(profile_id:profile.id,tenancy_history_id:tenancy_history.id,request_type:'move_out',reason:['MOVE_OUT','PAYMENT_DEFAULTED'],status:['New','RELEASED_INVENTORY'])
   if mo_move_request.nil?
      no_mo_request_present << email  #there is no MO move_request or there is no active MO
      next
   end
   mo_request = mo_move_request.last

   raise "move_out_date #{mo_request.schedule_date} already crossed by tenant #{email}" if mo_request.schedule_date < Date.today
   raise "#{tenancy_history.bed_id} #{tenancy_history.bed_type} is not available to cancel booking may be it is booked by another tenant" if mo_request.status == 'RELEASED_INVENTOY' && tenancy_history.bed.sold_out?

   custom_move_request = mo_move_request if mo_request.reason == 'PAYMENT_DEFAULTED' 
   
   MoveoutHelper.cancel_move_out(tenancy_history.id, MoveRequest.moveout_user_cancelled_status, notes, custom_move_request)
 end
end
