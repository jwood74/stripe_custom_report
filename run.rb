require "stripe"
require "date"
require "csv"
require 'rest-client'

require_relative 'options'

Stripe.api_key = $stripe_api

file = $save_location + "#{Time.now.strftime("%Y%m%d")}_log.csv"

CSV.open(file,"wb") do |csv|
	csv << ["payout_id","payout_amount","payout_date","transaction_type","transaction_id","transaction_total","transaction_net",
				"firstname","lastname","email","mobile","address","suburb","postcode","campaign"]

	payouts = Stripe::Payout.list(limit: 2)["data"]
	payouts.each do |p|
		charges = Stripe::BalanceTransaction.all(:payout => p["id"])["data"]

		charges.each do |c|

			tmp = Array.new

			if c['type'] == 'payout'
				next
			end

			case c['type']
				when 'payout'
					 next
				when 'charge'
					cg = Stripe::Charge.retrieve({:id => c['source'], :expand => ['balance_transaction']})

					## The below if statement fixes issue where subscriptions don't populate metadata in the charge - only on the customer
					if cg['customer'] != nil
						c['type'] = 'subscription'
						cus = Stripe::Customer.retrieve(cg['customer'])
						cg['metadata']['First Name'] = cus['metadata']['FirstName']
						cg['metadata']['Last Name'] = cus['metadata']['LastName']
						cg['metadata']['Email'] = cus['metadata']['Email']
						cg['metadata']['Mobile'] = cus['metadata']['Mobile']
						cg['metadata']['Address'] = cus['metadata']['Address']
						cg['metadata']['Suburb'] = cus['metadata']['Suburb']
						cg['metadata']['Postcode'] = cus['metadata']['Postcode']
						cg['metadata']['Campaign'] = cus['metadata']['Campaign']
					end

				when 'refund'
					cg = Stripe::Refund.retrieve({:id => c['source'], :expand => ['balance_transaction']})
					ch = Stripe::Charge.retrieve({:id => cg['charge'], :expand => ['balance_transaction']})

					## The below fixes issue where refunds don't include metadata on refund - but do on the linked charge
					cg['metadata']['First Name'] = ch['metadata']['First Name']
					cg['metadata']['Last Name'] = ch['metadata']['Last Name']
					cg['metadata']['Email'] = ch['metadata']['Email']
					cg['metadata']['Mobile'] = ch['metadata']['Mobile']
					cg['metadata']['Address'] = ch['metadata']['Address']
					cg['metadata']['Suburb'] = ch['metadata']['Suburb']
					cg['metadata']['Postcode'] = ch['metadata']['Postcode']
					cg['metadata']['Campaign'] = ch['metadata']['Campaign']

				else
					puts 'something unexpeected has been found!'
					next
			end

			tmp = [p['id'],p['amount']/100.to_f,Time.at(p['arrival_date']).to_date,c['type'],cg['id'],cg['amount'] / 100.to_f,cg['balance_transaction']['net'] / 100.to_f,
					cg['metadata']['First Name'],cg['metadata']['Last Name'],cg['metadata']['Email'],cg['metadata']['Mobile'],cg['metadata']['Address'],cg['metadata']['Suburb'],cg['metadata']['Postcode'],cg['metadata']['Campaign']]

			csv << tmp

		end
	end
end

exit
def send_simple_message(file)
	RestClient.post "https://api:key-#{$mg_api}"\
	"@api.mailgun.net/v3/#{$mg_domain}/messages",
	:from => $em_from,
	:to => $em_to,
	:cc => $em_to,
	:subject => "Stripe Log",
	:attachment => File.new(file),
	:text => "Attached is the latest Stipe payouts and payments for the last two payouts.",
	:html => "<html>Attached is the latest Stipe payouts and payments for the last two payouts.</html>"
end

send_simple_message(file)