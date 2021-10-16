# Extract blood pressure data from Apple Health XML

Run `ruby script.rb` in the same folder you have your exported xml.

I created this fork to use the heart rate data that the Withings BPM Connect simultaneously records with blood pressure data. The differences seem to specific to be incorporated into @effkay version.

The two differences I've discovered so far is that the time stamp is slightly later than the blood pressure readings. The second is that the blood pressure data is stored in two different iOS Health.

I'm hoping to use the script directly in a Rails app which is why I was happy to fork a Ruby script that parses Apple's verbose data.
