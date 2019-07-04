
When("we subscribe to the following statuses") do |table|

	@status_probe = RSMP::Probe.new(with_message: true, type: "StatusUpdate") do |item|
		#item[:message].attributes
	end

  @send_values = table.hashes
  @archive.probes.add @status_probe
  @sent_message = @remote_site.subscribe_to_status @component, @send_value, @status_probe
  expect(@sent_message).to_not be_nil
end

When("we unsubscribe to the following statuses") do |table|
  @send_values = table.hashes
  @sent_message = @remote_site.unsubscribe_to_status @component, table.hashes
end

Then(/we should receive a status update within (\d+) second(?:s)?/) do |timeout|
  @update_message = @remote_site.wait_for_status_update @component, timeout
  expect(@update_message).to_not be_nil
end

Then(/we should not receive a status update within (\d+) second(?:s)?/) do |timeout|
  @update_message = @remote_site.wait_for_status_update @component, timeout
  expect(@update_message).to be_nil
end

Then("the status update should include the component id") do
	expect(@update_message.attributes["cId"]).to eq(@component)
end

Then("the status update should include the correct status code ids") do
	@send_values.each_with_index do |sent,index|
		expected = {
			"cCI" => sent["cCI"],
			"q" => "recent"
		}
		sS = @update_message.attributes["sS"][index]
		got = {
			"cCI" => sS["cCI"],
			"q" => sS["q"]
		}
		expect(got).to eq(expected)
	end
end

Then("the status update should include values") do
	@send_values.each_with_index do |sent,index|
		sS = @update_message.attributes["sS"][index]
		expect(sS["s"]).to_not be_nil
	end
end

Then("the status update should include a timestamp that is within {float} seconds of our time") do |seconds|
	timestamp = RSMP.parse_time(@update_message.attributes["sTs"])
	difference = (timestamp - @update_message.timestamp).abs
	expect(difference).to be <= seconds
end

Then("we should receive empty status return values") do
end

