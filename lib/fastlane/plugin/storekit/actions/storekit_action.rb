require 'fastlane/action'
require_relative '../helper/storekit_helper'

module Fastlane
  module Actions
    class StorekitAction < Action
      def self.run(params)
				require 'pp'
        require 'spaceship'
        UI.message("The storekit plugin is working!")

        # Team selection passed though FASTLANE_ITC_TEAM_ID and FASTLANE_ITC_TEAM_NAME environment variables
        # Prompts select team if multiple teams and none specified
        UI.message("Login to App Store Connect (#{params[:username]})")
        Spaceship::ConnectAPI.login(params[:username], use_portal: false, use_tunes: true)
        UI.message("Login successful")

				app = Spaceship::ConnectAPI::App.find(params[:app_identifier])
		
				r = Spaceship::Tunes.client.iaps(app_id: app.id)

				products = []
				non_renewing_subs = []
				subscription_groups = {}

#				{"familyReferenceName"=>nil,
#				 "durationDays"=>0,
#				 "numberOfCodes"=>0,
#				 "maximumNumberOfCodes"=>100,
#				 "appMaximumNumberOfCodes"=>1000,
#				 "isEditable"=>false,
#				 "isRequired"=>false,
#				 "canDeleteAddOn"=>true,
#				 "errorKeys"=>nil,
#				 "isEmptyValue"=>false,
#				 "itcsubmitNextVersion"=>false,
#				 "adamId"=>"1600810028",
#				 "referenceName"=>"consume",
#				 "vendorId"=>"consume",
#				 "addOnType"=>"ITC.addons.type.consumable",
#				 "versions"=>
#					[{"screenshotUrl"=>nil,
#						"canSubmit"=>false,
#						"issuesCount"=>0,
#						"itunesConnectStatus"=>"missingMetadata"}],
#				 "purpleSoftwareAdamIds"=>["1594507974"],
#				 "lastModifiedDate"=>1639706393000,
#				 "isNewsSubscription"=>false,
#				 "iTunesConnectStatus"=>"missingMetadata"}

				r.each do |product|
					if product["addOnType"] == "ITC.addons.type.consumable" || product["addOnType"] == "ITC.addons.type.nonConsumable" || (product["addOnType"] == "ITC.addons.type.subscription" && product["durationDays"] == 0 )

						type =  if product["addOnType"] == "ITC.addons.type.subscription" && product["durationDays"] == 0
											"NonRenewingSubscription"
									  elsif product["addOnType"] == "ITC.addons.type.consumable"
										  "Consumable"											
										else
										  "NonConsumable"											
										end

						products << {
							"displayPrice": "",
							"familyShareable": false,
							"internalID": random_hex,
							"localizations": [
								{
									"description": "",
									"displayName": "",
									"locale": "en_US"
								}
							],
							"productID": product["vendorId"],
							"referenceName": product["referenceName"],
							"type": product["addOnType"] == "ITC.addons.type.consumable" ? "Consumable" : "NonConsumable"
						}
					elsif product["addOnType"] == "ITC.addons.type.recurring"
						group_name = product["familyReferenceName"]

						group = subscription_groups[group_name]
						if group.nil?
							group = {
								"id" => random_hex,
								"localizations" => [

								],
								"name" => group_name,
								"subscriptions" => []
							}
							subscription_groups[group_name] = group
						end

						group_id = group["id"]
						period = ""

						group["subscriptions"] << {	
							"adHocOffers": [

							],
							"displayPrice": "",
							"familyShareable": false,
							"groupNumber": 1,
							"internalID": random_hex,
							"introductoryOffer": nil,
							"localizations": [
								{
									"description": "",
									"displayName": "",
									"locale": "en_US"
								}
							],
							"productID": product["vendorId"],
							"recurringSubscriptionPeriod": period,
							"referenceName": product["referenceName"],
							"subscriptionGroupID": group_id,
							"type": "RecurringSubscription"
						}
					else
						pp product
					end
				end

				hash = {
					identifier: random_hex,
					nonRenewingSubscriptions: [],
					products: products,
					subscriptionGroups: subscription_groups.values,
					version: {
						major: "1",
						minor: "1"
					}
				}

				hash.to_json
      end

			def self.random_hex
				require 'securerandom'
				SecureRandom.hex[0...8].upcase
			end

      def self.description
        "Create a storekit configuration file"
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.details
        "Create a storekit configuration file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :username,
                                       env_name: "STOREKIT_USERNAME",
                                       description: "Your Apple ID Username for App Store Connect"),
          FastlaneCore::ConfigItem.new(key: :app_identifier,
                                       env_name: "STOREKIT_APP_IDENTIFIER",
                                       description: "The bundle identifier of your app",
                                       optional: false,
                                       code_gen_sensitive: true),
          FastlaneCore::ConfigItem.new(key: :team_id,
                                       env_name: "STOREKIT_TEAM_ID",
                                       description: "The ID of your App Store Connect team if you're in multiple teams",
                                       optional: true,
                                       skip_type_validation: true, # as we also allow integers, which we convert to strings anyway
                                       code_gen_sensitive: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_ID"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :team_name,
                                       env_name: "STOREKIT_TEAM_NAME",
                                       description: "The name of your App Store Connect team if you're in multiple teams",
                                       optional: true,
                                       code_gen_sensitive: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_NAME"] = value.to_s
                                       end),
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
