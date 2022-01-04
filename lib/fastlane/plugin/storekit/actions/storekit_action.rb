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

        valid_identifiers = self.get_revenuecat_product_identifiers(params)

				paths = Dir["*.storekit"].map do |path|
					File.absolute_path(path)
				end
				if paths.empty?
					UI.user_error!("Please add a StoreKit Configuration File to your Xcode project first and then rerun this in that directory")
        else
					path = UI.select("Which storekit file would you like to update?", paths)
				end

				json = make_storekit_config_json(params, valid_identifiers)

				File.write(path, json)
				UI.important("Updating StoreKit Configuration File at #{path}")

				nil
			end

      def self.get_revenuecat_product_identifiers(params)
        if params[:revenuecat_api_key].nil?
          return []
        end 

        require 'uri'
        require 'net/http'
        require 'openssl'
        require 'json'

        url = URI("https://api.revenuecat.com/v1/subscribers/app_user_id/offerings")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Accept"] = 'application/json'
        request["X-Platform"] = 'ios'
        request["Content-Type"] = 'application/json'
        request["Authorization"] = "Bearer #{params[:revenuecat_api_key]}"

        response = http.request(request)
        json = JSON.parse(response.read_body)

        identifiers = json['offerings'].map do |offering|
          offering['packages'].map do |package|
            package['platform_product_identifier']
          end
        end.flatten.uniq

        UI.message("Found RevenueCat product identifiers: #{identifiers.join(', ')}")

        return identifiers
      end

			def self.make_storekit_config_json(params, valid_identifiers)
				app = Spaceship::ConnectAPI::App.find(params[:app_identifier])
		
				r = Spaceship::Tunes.client.iaps(app_id: app.id)

				products = []
				non_renewing_subs = []
				subscription_groups = {}

				r.each do |product|
          full_iap = Spaceship::Tunes.client.load_iap(app_id: app.id, purchase_id: product["adamId"])
          require 'pp'

          localizations = []

          if (version = full_iap['versions'].first)
            (version['details']['value'] || []).each do |detail|
              locale_code = detail['value']['localeCode']
              name = detail['value']['name']['value']
              description = detail['value']['description']['value']

              localizations << {
                "description": description,
                "displayName": name,
                "locale": locale_code
              }
            end
          end

          if !valid_identifiers.empty? && !valid_identifiers.include?(product["vendorId"])
            UI.important("Not found on RevenueCat. Rejecting '#{product["vendorId"]}'")
            next
          end

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
							"localizations": localizations,
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
							"localizations": localizations,
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
          FastlaneCore::ConfigItem.new(key: :revenuecat_api_key,
                                       env_name: "STOREKIT_REVENUECAT_API_KEY",
                                       description: "The RevenueCat API Key for your Apple app used to filter only IAPs that are used in offerings",
                                       optional: true,
                                       code_gen_sensitive: true)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
