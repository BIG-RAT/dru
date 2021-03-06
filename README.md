# Device Record Updater (dru)
Perform mass updates to multiple attributes on either iOS or MacOS device records stored on your Jamf Pro server.
![alt text](https://github.com/BIG-RAT/dru/blob/master/images/dru.png "Device Record Updater")
Download: [dru](https://github.com/BIG-RAT/dru/releases/download/current/dru.zip)

Provides the option to back-up a device record before updating it.  Note this is not a full back-up of all the device attributes but rather attributes we can change; name, asset tag, site, location attributes...  Backups are stored in:<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;```~/Library/Application\ Support/dru/backups``` <br>
and can be dropped back into the app to restore values.

Preview potential changes before committing them.
Colors are used to help identify changes in an attribute value:
* aqua - adding a value.
* yellow - changing an existing value.
* red - removing an existing value.

To remove the value of an attribute enter a space as the value, leaving the value blank will leave the attribute value unchanged.
![alt text](https://github.com/BIG-RAT/dru/blob/master/images/dru.preview.png "Preview")
Note: only attributes that have a value or have a value being set are displayed.  Sites are an exception to this rule.

A header row is required in the data file.  A template can be created from the file menu:

![alt text](https://github.com/BIG-RAT/dru/blob/master/images/dru.sampleFile.png "Template")

The application will look for known headers; computer name, display name, serial number, serial_number, udid, asset tag, asset_tag, full name, username, email address, email_address, building, department,position, room, phone number, user phone number, device phone number, phone, site.  Other headers will be classified as extensions attributes.  As a result you cannot have an extension attributed titled the same as a know header.  For example you can't have an extension attribute called site as it is defined as a known header (taken by a built in attribute), or 'computer name' as it is associated with the built in attribute 'name' from a computer record.  Note, using these known headers allows one to export an advanced search to create a data file.
Currently updates are based on serial number, that being the only required data field (column).

**To Do:**
* Logging.
* Better formatting of the preview page.
* preference file.
* More error checking.
* Better way to clear attribute value(s).
* Help file.
* Ability to match off an attribute other than serial number.
* Ability to use a delimiter other than a comma.
