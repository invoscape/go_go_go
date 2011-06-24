GoGoGo
======

GoGoGo is a plugin to manage __uploading__ your app. It does the following:

+	Prepare a list of files to be uploaded using __svn__ 
+	Upload the files
+	Record the current revision number by uploading a go_go_go.yml file with release details to the host

It is designed to be simple and manage __uploading only__ for any rails or sinatra app. It currently supports only svn.

Dependencies 
------------
+	ruby >= 1.8.7
+	rails >= 3.0
+	logger
+	yaml
+	svn [command line](http://www.collab.net/downloads/subversion/) availability

Installation
============
+	Copy the entire plugin into __vendor/plugins/__ folder or execute

		rails plugin install git://github.com/invoscape/go_go_go.git
+	Execute

		rails generate go_go_go settings
	this will create a go_go_go.yml file in the __config__ folder of your app
+	Add your host details in the go_go_go.yml file created 
	

Usage
=====
GoGoGo exposes rake commands to make your life simpler!

+	To make releases till the current head on the fly

		rake gogogo:release
	This command assumes the presence of a go_go_go.yml file in your server	with details of previous releases

+	To make release from a particular svn revision number

		rake gogogo:release_from[1]
	This is an example of releasing from the first revision till the head revision. Typically this is used for the first time release.

+	To make releases upto a particular svn revision number

		rake gogogo:release_upto[1620] 
	 This command typically triggers a release till the specified release irrespective of the head

+	To make releases between revision numbers

		rake gogogo:release_from_upto[386,738]
	Here the list of changes between the two specified versions are alone uploaded.

__Home page__ - [invoscape.com/open_source#gogogo](http://www.invoscape.com/open_source#gogogo)

__Want to contribute ?__ - Drop in a mail to opensource(at)invoscape(dot)com

Please do report any issues you face - [issues](https://github.com/invoscape/go_go_go/issues)

__Why "GoGoGo" ?__ - We all love CS, don't we? :) 

Copyright &copy; [Invoscape Technologies Pvt. Ltd.](http://www.invoscape.com), released under the MIT license