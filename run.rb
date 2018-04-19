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

				tmp = Array.new

				payouts = Stripe::Payout.list(limit: 2)["data"]
				payouts.each do |p|
					charges = Stripe::BalanceTransaction.all(:payout => p["id"])["data"]
	
					charges.each do |c|

						if c['type'] == 'payout'
							next
						end

						case c['type']
							when 'payout'
								 next
							when 'charge'
								cg = Stripe::Charge.retrieve({:id => c['source'], :expand => ['balance_transaction']})
							when 'refund'
								cg = Stripe::Refund.retrieve({:id => c['source'], :expand => ['balance_transaction']})
							else
								puts 'something unexpeected has been found!'
								next
						end

						tmp = [p['id'],p['amount']/100.to_f,Time.at(p['arrival_date']).to_date,c['type'],cg['id'],cg['amount'] / 100.to_f,cg['balance_transaction']['net'] / 100.to_f,cg['metadata']['First Name'],cg['metadata']['Last Name'],cg['metadata']['Email'],cg['metadata']['Mobile'],cg['metadata']['Address'],cg['metadata']['Suburb'],cg['metadata']['Postcode'],cg['metadata']['Campaign']]
						csv << tmp

					end
				end
end


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